# 07 — Motor de Sincronização

A parte mais difícil do app. Leia inteiro antes de escrever a primeira linha.

## O contrato

```
                    ┌──────────────────────┐
   escrita local →  │   SQLite (Drift)     │  → Stream → UI
                    │   + tabela outbox    │
                    └──────────┬───────────┘
                               │
                        ┌──────▼───────┐
                        │  SyncEngine  │
                        └──────┬───────┘
                     push │         │ pull
                          ▼         ▼
                    ┌─────────────────────┐
                    │ Supabase (Postgres) │
                    │ PostgREST + Realtime│
                    └─────────────────────┘
```

**Push** é `upsert` direto no PostgREST, tabela por tabela, na ordem de dependência.
**Pull** é uma chamada só ao RPC `sync_pull`, que devolve o delta de todas as tabelas.

A assimetria é intencional. Push por RPC exigiria uma função plpgsql fazendo upsert dinâmico em 15 tabelas — código difícil de auditar, e que teria de reimplementar as checagens que a RLS já faz de graça no PostgREST. Pull por PostgREST seriam 15 requisições HTTP a cada sincronização; por RPC, é uma.

## Estados de uma linha

| Estado | Como reconhecer | Significado |
|---|---|---|
| Limpa | `is_dirty = 0`, sem outbox | Igual ao servidor |
| Suja | `is_dirty = 1`, com outbox | Alterada localmente, ainda não subiu |
| Em voo | outbox com `attempts > 0` | Push tentado, resposta desconhecida |
| Apagada | `deleted_at != null` | Soft delete, propaga como atualização |

`is_dirty` é o que decide conflito. Ver adiante.

## Push

### Ordem obrigatória

FK é validada no servidor. Enviar um lançamento antes da conta a que ele pertence devolve `23503 foreign_key_violation`. A ordem correta:

```dart
const kPushOrder = [
  'households',
  'household_members',
  'accounts',
  'categories',
  'merchants',
  'recurrences',
  'receipts',
  'transactions',        // depende de accounts, categories, merchants,
                         // recurrences, receipts
  'transaction_splits',
  'budgets',
  'goals',
  'goal_contributions',
  'payslips',
  'payslip_items',
  'settlements',
];
```

O pull não precisa dessa ordem porque o SQLite local aplica tudo dentro de uma transação, e `PRAGMA foreign_keys` é suspenso durante ela (ver adiante).

### Implementação

```dart
// lib/data/sync/sync_engine.dart
class SyncEngine {
  SyncEngine(this._db, this._supabase, this._connectivity);

  final AppDatabase _db;
  final SupabaseClient _supabase;
  final Connectivity _connectivity;

  bool _running = false;
  Timer? _retryTimer;

  /// Ponto de entrada único. Reentrante: chamadas concorrentes viram
  /// no-op, porque dois pushes simultâneos duplicariam envio e
  /// embaralhariam a ordem de FK.
  Future<SyncResult> sync({bool force = false}) async {
    if (_running) return SyncResult.alreadyRunning;
    if (!force && !await _hasConnection()) return SyncResult.offline;

    _running = true;
    try {
      await _push();          // sobe o local primeiro: se o servidor
                              // mudou a mesma linha, o pull seguinte
                              // já traz o resultado consolidado
      await _pull();
      await _uploadPendingPhotos();
      return SyncResult.ok;
    } on PostgrestException catch (e) {
      _scheduleRetry();
      return SyncResult.error('${e.code}: ${e.message}');
    } catch (e) {
      _scheduleRetry();
      return SyncResult.error(e.toString());
    } finally {
      _running = false;
    }
  }

  Future<void> _push() async {
    for (final table in kPushOrder) {
      final pending = await _db.syncDao.pendingFor(table, limit: 200);
      if (pending.isEmpty) continue;

      // Deduplica por row_id mantendo a última versão: editar o mesmo
      // lançamento cinco vezes offline deve gerar um envio, não cinco.
      final byId = <String, OutboxRow>{};
      for (final row in pending) {
        byId[row.rowId] = row;
      }

      final payload = byId.values.map((r) => jsonDecode(r.payload)).toList();

      try {
        await _supabase.from(table).upsert(payload, onConflict: 'id');
        await _db.syncDao.clearOutbox(byId.values.map((r) => r.seq));
        await _db.syncDao.markClean(table, byId.keys);
      } on PostgrestException catch (e) {
        await _handlePushError(table, byId.values.toList(), e);
        rethrow;
      }
    }
  }
```

### Erros de push, um a um

Cada código tem tratamento diferente. Tratar tudo como "tenta de novo" produz fila travada para sempre.

```dart
  Future<void> _handlePushError(
    String table, List<OutboxRow> rows, PostgrestException e,
  ) async {
    switch (e.code) {
      case '23503':  // foreign_key_violation
        // A linha-pai ainda não subiu (ou foi apagada no servidor).
        // Adiar: a próxima rodada provavelmente já terá o pai.
        // Depois de 5 tentativas, é órfã de verdade — descarta e
        // registra, porque insistir para sempre trava a fila inteira.
        await _db.syncDao.deferOrDrop(rows, maxAttempts: 5);

      case '42501':  // insufficient_privilege — barrado pela RLS
        // Não adianta tentar de novo: o usuário perdeu acesso, mudou
        // de papel, ou saiu da casa. Descarta e sinaliza para a UI.
        await _db.syncDao.dropAndFlagConflict(rows, reason: 'sem permissão');

      case '23505':  // unique_violation
        // Tipicamente merchants com o mesmo normalized_name criado nos
        // dois celulares offline. Resolve no pull: adota o id do
        // servidor e reaponta as referências locais.
        await _db.syncDao.dropAndFlagConflict(rows, reason: 'duplicado');

      case '23514':  // check_violation
        // Bug de escrita do app. Nunca deve chegar aqui em produção;
        // se chegar, insistir só empilha erro.
        await _db.syncDao.dropAndFlagConflict(rows, reason: 'dado inválido');

      case 'PGRST301':  // JWT expirado
        await _supabase.auth.refreshSession();
        // não descarta nada: a próxima rodada reenvia

      default:
        await _db.syncDao.bumpAttempts(rows, error: e.message);
    }
  }
```

## Pull

```dart
  Future<void> _pull() async {
    final householdId = await _db.syncDao.activeHousehold();
    var cursor = await _db.syncDao.cursor();
    var guard = 0;

    while (guard++ < 20) {   // teto de segurança contra laço infinito
      final res = await _supabase.rpc('sync_pull', params: {
        'p_household': householdId,
        // SOBREPOSIÇÃO DE 2 SEGUNDOS. Ver explicação abaixo — não
        // remova achando que é ineficiência.
        'p_since': cursor.subtract(const Duration(seconds: 2)).toIso8601String(),
        'p_limit': 1000,
      }) as Map<String, dynamic>;

      final data = res['data'] as Map<String, dynamic>;

      // Uma transação só para todo o lote: ou o dispositivo fica
      // consistente, ou não muda nada. Um pull aplicado pela metade
      // (transações sem as contas) deixaria a UI mostrando lixo.
      await _db.transaction(() async {
        // FK suspensa dentro da transação: o lote chega em ordem
        // arbitrária, e o SQLite validaria cada linha na hora. Com
        // defer_foreign_keys a checagem acontece no COMMIT, quando
        // tudo já está lá.
        await _db.customStatement('PRAGMA defer_foreign_keys = ON');
        for (final table in kPullOrder) {
          final rows = (data[table] as List?) ?? const [];
          for (final row in rows.cast<Map<String, dynamic>>()) {
            await _applyRemoteRow(table, row);
          }
        }
      });

      cursor = DateTime.parse(res['cursor'] as String);
      await _db.syncDao.saveCursor(cursor);

      if (res['has_more'] != true) break;
    }
  }
```

### Por que a sobreposição de 2 segundos

O cursor é um `timestamptz`, e transações do Postgres **não commitam na ordem em que começam**.

Cenário concreto: a transação A grava uma linha com `updated_at = 10:00:00.100` e demora para commitar. A transação B grava `updated_at = 10:00:00.150` e commita imediatamente. Um pull que acontece nesse intervalo enxerga só a linha de B e avança o cursor para `10:00:00.150`. Quando A finalmente commita, sua linha tem timestamp **anterior** ao cursor — e nunca mais será puxada. Dado perdido, silenciosamente, para sempre.

A sobreposição de 2 segundos cobre a janela realista de commit. Reler linha repetida é inofensivo porque **todo apply é upsert por `id`**, ou seja, idempotente. O custo é algumas linhas a mais por sync; o benefício é não perder dado.

Um sync perfeitamente correto usaria o horizonte de visibilidade de transações (`pg_snapshot_xmin`) em vez de relógio. Para uma família de quatro pessoas, a sobreposição resolve o mesmo problema com uma fração da complexidade — e essa é a troca certa aqui.

## Resolução de conflito

**Regra: last-write-wins por `updated_at` do servidor, com preferência local para linha suja.**

```dart
Future<void> _applyRemoteRow(String table, Map<String, dynamic> remote) async {
  final id = remote['id'] as String;
  final local = await _db.syncDao.findRow(table, id);

  // 1. Não existe local → insere.
  if (local == null) {
    await _db.syncDao.insertFromRemote(table, remote);
    return;
  }

  // 2. Local limpo → o servidor é a verdade. Sobrescreve.
  if (!local.isDirty) {
    await _db.syncDao.updateFromRemote(table, remote);
    return;
  }

  // 3. Local sujo: há uma edição minha que ainda não subiu. Comparar
  //    timestamps aqui seria errado — o updated_at local é relógio de
  //    celular e o remoto é relógio de servidor, grandezas diferentes.
  //    A edição local ainda está na outbox e vai subir na próxima
  //    rodada, então ela vence por ora. Mantém o local e não toca em
  //    nada.
  //
  //    Não é perda de dado: a alteração do servidor será sobrescrita
  //    pela minha no push seguinte, que é exatamente o comportamento
  //    de last-write-wins com o meu write sendo o último.
  return;
}
```

### O que isso significa na prática

Você e sua esposa editam o mesmo lançamento offline, ao mesmo tempo. Quem sincronizar por último vence, e a edição do outro se perde.

Isso é aceitável, e não por preguiça. Num app de finanças familiar, a operação dominante é **criar** lançamento, não editar — e criações nunca conflitam, porque cada uma tem `id` próprio gerado no cliente. Edição simultânea do mesmo registro por duas pessoas em janela offline é raríssima. CRDT ou merge por campo resolveriam com correção total, ao custo de multiplicar a complexidade do motor — troca ruim para o ganho.

Onde o conflito **doeria** de verdade é em saldo de conta, e por isso saldo não é um campo: é `SUM(signed_amount_cents)`. Dois celulares somando lançamentos diferentes convergem para o mesmo total sem precisar de merge nenhum. **A escolha de modelagem eliminou a classe de conflito que importava.**

### Conflito visível para o usuário

Quando `_handlePushError` descarta uma linha (`dropAndFlagConflict`), ela vai para uma lista em Ajustes › Sincronização, mostrando o que foi rejeitado e por quê. Não some em silêncio. É uma tela feia que quase nunca é aberta, e vale cada minuto: sem ela, "sumiu um lançamento" vira uma sessão de depuração às cegas.

## Quando o sync roda

| Gatilho | Implementação |
|---|---|
| App abre | Chamada no `bootstrap()` |
| Volta do background | `AppLifecycleState.resumed` |
| Conexão volta | `Connectivity().onConnectivityChanged` |
| Depois de escrever | Debounce de 3 segundos — evita 10 syncs ao cadastrar 10 lançamentos seguidos |
| Realtime avisou | Canal Postgres Changes |
| Periódico em background | `workmanager`, a cada 4 horas, só com rede |
| Puxar para atualizar | Manual, com `force: true` |

### Realtime

```dart
void _listenRealtime(String householdId) {
  _supabase
      .channel('household:$householdId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'transactions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'household_id',
          value: householdId,
        ),
        // Deliberadamente NÃO aplica o payload do evento direto no
        // banco local. O evento é só um sino: dispara um pull normal,
        // que passa por todo o caminho de conflito e cursor. Aplicar
        // o payload direto criaria um segundo caminho de escrita com
        // regras próprias — dois caminhos, dois conjuntos de bugs.
        callback: (_) => _debouncedSync(),
      )
      .subscribe();
}
```

Assine só `transactions`. É a tabela que muda a toda hora e que justifica atualização imediata; o resto chega no pull seguinte. A cota gratuita dá 200 conexões simultâneas e 2 milhões de mensagens por mês — folgado para uma família, mas não há motivo para gastar em tabela que muda uma vez por semana.

## Upload de fotos

Fila separada da outbox, porque binário tem política diferente:

```dart
Future<void> _uploadPendingPhotos() async {
  final pending = await _db.syncDao.pendingUploads(limit: 5);
  final wifiOnly = await _db.settings.getBool('upload_wifi_only') ?? false;
  if (wifiOnly && !await _isWifi()) return;

  for (final item in pending) {
    final file = File(item.localPath);
    if (!file.existsSync()) {
      // Usuário limpou o cache do sistema. Não há o que recuperar;
      // marca o recibo como perdido em vez de tentar para sempre.
      await _db.syncDao.dropUpload(item.receiptId, reason: 'arquivo removido');
      continue;
    }
    try {
      await _supabase.storage.from('receipts').upload(
            item.storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      await _db.syncDao.completeUpload(item.receiptId);
    } catch (e) {
      await _db.syncDao.bumpUploadAttempt(item.receiptId, e.toString());
    }
  }
}
```

Cinco por rodada, para não consumir a franquia de dados de uma vez quando houver acúmulo.

## Backoff

```dart
void _scheduleRetry() {
  final attempt = _consecutiveFailures.clamp(0, 6);
  // 5s, 10s, 20s, 40s, 80s, 160s, 320s — teto de ~5 minutos
  final delay = Duration(seconds: 5 * (1 << attempt));
  // Jitter: sem ele, dois celulares que perderam a rede juntos voltam
  // no mesmo milissegundo e colidem de novo.
  final jitter = Duration(milliseconds: Random().nextInt(1000));
  _retryTimer?.cancel();
  _retryTimer = Timer(delay + jitter, () => sync());
}
```

## Sync em background

```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    // Isolate novo: nada da inicialização do app existe aqui. Tudo
    // precisa ser refeito. Esquecer isso produz o clássico
    // "Supabase.instance not initialized" só em background.
    WidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
    final db = AppDatabase();          // shareAcrossIsolates cuida do lock
    final engine = SyncEngine(db, Supabase.instance.client, Connectivity());
    final result = await engine.sync();
    await db.close();
    return result == SyncResult.ok;    // false faz o WorkManager reagendar
  });
}
```

Restrição: `NetworkType.connected`, `requiresBatteryNotLow: true`. Ambos os sistemas matam trabalho em background agressivamente — o intervalo de 4 horas é um pedido, não uma garantia, e o app não pode depender dele para correção. É otimização de conveniência, nada mais.

## Primeira sincronização

Dispositivo novo, ou banco local apagado: cursor em `-infinity`, e o pull traz tudo em páginas de 1.000.

Mostre progresso. Uma família com dois anos de histórico tem uns 8 mil lançamentos — cabe em oito páginas, poucos segundos em rede decente, mas uma tela travada sem feedback nesse tempo parece um app quebrado.

## Testes obrigatórios

Sem estes, o motor não pode ser considerado pronto:

| Cenário | Resultado esperado |
|---|---|
| Criar offline, voltar rede | Linha aparece no servidor e no outro dispositivo |
| Criar em dois dispositivos offline | Ambas as linhas sobrevivem (ids diferentes) |
| Editar a mesma linha nos dois | Última a sincronizar vence, sem crash nem duplicata |
| Apagar em A enquanto B está offline | B recebe `deleted_at` e a linha some da UI de B |
| Push com FK faltando | Adia, depois resolve quando o pai sobe |
| Push barrado pela RLS | Descarta e aparece na lista de conflitos |
| JWT expirado no meio do push | Renova e conclui |
| Matar o app durante o push | Outbox intacta; próximo boot reenvia sem duplicar |
| 5.000 lançamentos na primeira carga | Conclui, com progresso visível |
| Dois syncs simultâneos | O segundo vira no-op |

O teste de "matar o app no meio do push" é o que valida a decisão de gravar dado e outbox na mesma transação SQLite. Se a implementação separar isso em dois `await`, este teste falha — e é assim que se descobre.
