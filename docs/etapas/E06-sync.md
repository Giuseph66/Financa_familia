# E06 — Motor de Sincronização

Referências: [07-sync-engine.md](../07-sync-engine.md)

**A etapa mais difícil do projeto.** Leia [07-sync-engine.md](../07-sync-engine.md) inteiro antes de escrever a primeira linha. Não improvise: cada decisão ali tem um modo de falha concreto por trás.

## Tarefas

### 1. Mappers

`lib/data/sync/mappers/` — conversão entre linha do Drift e JSON do PostgREST, um por tabela.

Cuidados que causam bug silencioso:

- **`DateTime` sempre em UTC ISO-8601.** `toIso8601String()` num `DateTime` local grava sem fuso e o servidor interpreta como UTC, deslocando tudo em 3 horas.
- **`null` explícito vs campo ausente.** Omitir um campo no upsert mantém o valor antigo; mandar `null` apaga. São coisas diferentes e o mapper precisa ser deliberado.
- **`signed_amount_cents` não vai no push.** É coluna gerada no Postgres, e mandá-la causa erro.
- **`updated_at` não vai no push.** O trigger do servidor sobrescreve; mandar é ruído.

### 2. Outbox

`lib/data/sync/outbox.dart`. Enfileirar, listar pendentes por tabela, deduplicar por `row_id` mantendo a última versão, limpar, incrementar tentativa, adiar, descartar com motivo.

Deduplicar importa: editar o mesmo lançamento cinco vezes offline deve gerar um envio, não cinco.

### 3. Cursor

`lib/data/sync/cursor_store.dart`, em cima de `sync_state`. Um cursor global por casa é suficiente — cursor por tabela seria mais fino e não compensa a complexidade.

### 4. Push

Ordem de FK obrigatória, exatamente como em [07-sync-engine.md](../07-sync-engine.md#ordem-obrigatória). Enviar lançamento antes da conta devolve `23503`.

Lotes de 200. Tratamento de erro **por código**, não genérico:

| Código | Ação |
|---|---|
| `23503` FK | adia; descarta após 5 tentativas |
| `42501` RLS | descarta e sinaliza conflito — tentar de novo nunca vai funcionar |
| `23505` único | descarta e sinaliza; resolve no pull |
| `23514` check | descarta e sinaliza; é bug de escrita |
| `PGRST301` JWT | renova sessão e reenvia |
| outros | incrementa tentativa, backoff |

Tratar tudo como "tenta de novo" trava a fila para sempre no primeiro erro permanente.

### 5. Pull

RPC `sync_pull`, uma chamada por rodada, paginado por `has_more`.

Dois detalhes que não podem ser omitidos:

**Sobreposição de 2 segundos no cursor.** Transações do Postgres não commitam na ordem em que começam; sem a sobreposição, uma linha commitada tarde fica com timestamp anterior ao cursor e nunca mais é puxada. Reler é inofensivo porque todo apply é upsert por `id`.

**`PRAGMA defer_foreign_keys = ON` dentro da transação do apply.** O lote chega em ordem arbitrária; sem isso o SQLite rejeita linha por linha.

O lote inteiro em **uma** transação: ou o dispositivo fica consistente, ou não muda nada.

### 6. Conflito

A regra dos três casos de [07-sync-engine.md](../07-sync-engine.md#resolução-de-conflito): não existe local → insere; local limpo → servidor vence; local sujo → mantém local, porque a edição ainda está na outbox e vai subir na próxima rodada.

Não compare `updated_at` local com remoto no caso 3: são relógios diferentes (celular vs servidor) e a comparação não significa nada.

Conflitos descartados vão para uma lista visível em Ajustes › Sincronização. Não somem em silêncio.

### 7. Gatilhos

Abrir o app, voltar do background, conexão voltar, após escrever (debounce de 3s), evento de Realtime, periódico via `workmanager` a cada 4h, e o puxar-para-atualizar manual.

Reentrante: dois `sync()` simultâneos, o segundo vira no-op.

### 8. Realtime

Assine só `transactions`, filtrado por `household_id`. O evento é **um sino, não um dado**: dispare um pull normal, não aplique o payload direto. Aplicar direto criaria um segundo caminho de escrita com regras próprias.

### 9. Fila de upload

Separada da outbox. Cinco por rodada, opção de só Wi-Fi, e descarte quando o arquivo local sumiu.

### 10. Background

`callbackDispatcher` com `@pragma('vm:entry-point')`. **Isolate novo não herda nada** — refaça `Supabase.initialize` e abra o `AppDatabase` de novo, ou o clássico "Supabase.instance not initialized só em background" aparece.

### 11. Interface de status

- Faixa "Offline · N pendentes" no topo
- Barra de progresso de 2dp sob a AppBar durante o sync
- Ajustes › Sincronização: última sincronização, pendentes, conflitos, botão "Sincronizar agora", botão "Recriar banco local"

"Recriar banco local" é a válvula de escape: apaga o SQLite e puxa tudo do zero. Só habilite com a outbox vazia, e deixe isso explícito na tela — o que está na outbox e não subiu se perde.

### 12. Testes

Todos os cenários da tabela em [07-sync-engine.md](../07-sync-engine.md#testes-obrigatórios). Sem eles a etapa não está pronta.

## DoD

- [ ] Criar offline e restaurar rede: chega no servidor
- [ ] Criar em dois dispositivos offline: ambos sobrevivem
- [ ] Editar a mesma linha nos dois: última vence, sem crash nem duplicata
- [ ] Apagar em A com B offline: B recebe o `deleted_at` e a linha some
- [ ] Push com FK faltando adia e depois resolve
- [ ] Push barrado pela RLS descarta e aparece na lista de conflitos
- [ ] JWT expirado no meio do push renova e conclui
- [ ] Matar o app durante o push: outbox intacta, sem duplicata no reenvio
- [ ] 5.000 lançamentos na primeira carga concluem com progresso visível
- [ ] Dois syncs simultâneos: o segundo é no-op
- [ ] Realtime dispara pull em outro dispositivo em menos de 10s
- [ ] Sync em background funciona com o app fechado
- [ ] Nenhuma tela lê do Supabase: `grep -rn "supabase" lib/features/` sem resultado

Commit: `feat(e06): motor de sincronização offline-first`
