# 03 — Setup do Supabase

## Instalar a CLI

Não está instalada no ambiente. Sem `npm i -g` — o pacote npm da Supabase CLI é depreciado e falha em Node 24.

```bash
curl -fsSL https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz \
  | tar -xz -C /tmp
sudo mv /tmp/supabase /usr/local/bin/supabase
supabase --version
```

## Ligar o repositório ao projeto

```bash
cd ~/Neurelix/Finança
supabase init                       # cria supabase/config.toml
supabase login                      # abre o navegador
supabase link --project-ref skkequjojwmivdmaqczb
```

O `link` pede a senha do banco (a que foi definida ao criar o projeto). Se estiver perdida: Dashboard › Settings › Database › Reset database password. Guarde num gerenciador de senhas — **essa senha não vai para nenhum arquivo do repositório**.

## Aplicar as migrations

Os arquivos em [sql/](sql/) estão numerados na ordem de dependência. A CLI exige prefixo de timestamp, então copie renomeando:

```bash
mkdir -p supabase/migrations
i=0
for f in docs/sql/0*.sql; do
  i=$((i+1))
  ts=$(printf "202608041200%02d" "$i")
  cp "$f" "supabase/migrations/${ts}_$(basename "${f%.sql}" | cut -d_ -f2-).sql"
done
ls supabase/migrations
```

Resultado esperado, nesta ordem:

```
20260804120001_foundation.sql
20260804120002_identity.sql
20260804120003_core.sql
20260804120004_planning_income.sql
20260804120005_views.sql
20260804120006_rls.sql
20260804120007_rpc.sql
20260804120008_seed_categories.sql
20260804120009_storage.sql
```

Valide localmente **antes** de tocar no projeto remoto. Precisa de Docker:

```bash
supabase start          # sobe Postgres local na porta 54322
supabase db reset       # aplica todas as migrations do zero
```

`db reset` é o teste de verdade das migrations: roda tudo em banco vazio, na ordem, e falha alto se houver dependência quebrada. Rode isso a cada migration nova.

Depois de passar local:

```bash
supabase db push
```

Se o Docker não estiver disponível, dá para colar cada arquivo no SQL Editor do Dashboard, **na ordem numérica**. Funciona, mas você perde o histórico versionado — só faça como último recurso.

## Configurar Auth

Dashboard › Authentication › Providers:

- **Email** ligado. Em desenvolvimento, desligue "Confirm email" para não depender de caixa de entrada a cada teste. **Religue antes de qualquer usuário real** — sem confirmação, qualquer um cria conta com o e-mail de outra pessoa.
- Minimum password length: 8.
- Leaked password protection: ligado (o Supabase checa contra a base do HaveIBeenPwned).

Authentication › URL Configuration › Redirect URLs — necessário para o deep link do e-mail de recuperação de senha voltar para o app:

```
br.com.neurelix.financa://login-callback
financa://login-callback
```

Authentication › Rate limits: deixe o padrão. A cota gratuita já limita e-mails a 2 por hora, o que é suficiente para uso pessoal e não vale a pena mexer.

## Verificar a RLS

Depois do push, Dashboard › Advisors › Security. **A lista tem que estar vazia.** Os avisos que aparecem se algo saiu errado:

| Aviso | O que significa | Onde corrigir |
|---|---|---|
| `rls_disabled_in_public` | Tabela pública sem RLS — vazamento total | Bloco `do $$` no topo de `0006_rls.sql` |
| `security_definer_view` | View sem `security_invoker` — ignora a RLS de quem consulta | `0005_views.sql` |
| `function_search_path_mutable` | `SECURITY DEFINER` sem `search_path` fixo — escalonamento de privilégio | Adicione `set search_path = public, pg_temp` |
| `auth_users_exposed` | View expondo `auth.users` | Não deve ocorrer; nenhuma view aqui toca essa tabela |

Teste manual, no SQL Editor, que vale mais que os advisors:

```sql
-- Simula um usuário qualquer sem casa nenhuma
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000000"}';
select count(*) from transactions;   -- TEM que devolver 0
select count(*) from payslips;       -- TEM que devolver 0
reset role;
```

Se qualquer uma devolver linha, **pare tudo e conserte antes de escrever uma linha de Flutter.**

## Variáveis de ambiente

As credenciais vão para `.env.dev` e `.env.prod` na raiz, **fora do git**:

```bash
# .env.dev
SUPABASE_URL=https://skkequjojwmivdmaqczb.supabase.co
SUPABASE_ANON_KEY=sb_publishable_sgAvB-4aV-ZCns0Xn7A4vQ_JrdR4pe2
APP_ENV=dev
```

`.gitignore`:

```gitignore
.env*
!.env.example
*.keystore
*.jks
key.properties
ios/Runner/GoogleService-Info.plist
**/*.g.dart
**/*.freezed.dart
```

Carregar no build:

```bash
flutter run --dart-define-from-file=.env.dev
flutter build apk --release --dart-define-from-file=.env.prod
```

Leitura em `lib/core/env/env.dart`:

```dart
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  static bool get isDev => appEnv == 'dev';

  /// Chamado no bootstrap. Falha cedo e alto: rodar sem as variáveis
  /// produz um erro de rede incompreensível na primeira tela, e o
  /// tempo perdido depurando isso é sempre maior que o custo desta
  /// verificação.
  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL/SUPABASE_ANON_KEY ausentes. '
        'Rode com --dart-define-from-file=.env.dev',
      );
    }
  }
}
```

### Sobre a chave no aplicativo

A `sb_publishable_...` é projetada para viver no cliente — ela apenas identifica o projeto e concede o papel `anon`/`authenticated`. Qualquer pessoa consegue extraí-la do APK com `unzip` e `strings`, e isso é esperado. **A segurança do sistema é a RLS, não a chave.** É por isso que o teste de RLS acima é bloqueante.

Duas regras que não se negociam:

**A `service_role` key nunca entra no app.** Ela ignora RLS por completo — quem a tiver lê e escreve tudo de todas as famílias. Ela vive só em Edge Functions e em variáveis de ambiente do servidor.

**Nada de senha ou token em `SharedPreferences`.** O `supabase_flutter` já persiste a sessão; configure-o para usar armazenamento seguro:

```dart
await Supabase.initialize(
  url: Env.supabaseUrl,
  anonKey: Env.supabaseAnonKey,
  authOptions: const FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce,
    localStorage: SecureLocalStorage(),   // Keychain / EncryptedSharedPreferences
  ),
  realtimeClientOptions: const RealtimeClientOptions(
    logLevel: RealtimeLogLevel.error,
  ),
);
```

PKCE em vez do fluxo implícito porque o token não passa pela URL de redirect, onde poderia ser capturado por outro app registrado no mesmo esquema.

## Cota gratuita — o que vigiar

| Recurso | Limite | Consumo estimado (família de 4) |
|---|---|---|
| Banco | 500 MB | ~15 MB/ano com 300 lançamentos/mês |
| Storage | 1 GB | ~200 KB/recibo → ~5.000 recibos |
| Banda | 5 GB/mês | Sync é delta e comprimido; sobra muito |
| MAU | 50.000 | 4 |
| Edge Functions | 500k chamadas/mês | Nenhuma no MVP |

Nenhum limite chega perto de apertar. **O risco real da cota gratuita é outro: o projeto é pausado após 7 dias sem nenhuma requisição.** Em produção com uso diário isso nunca acontece. Durante o desenvolvimento, se ficar uma semana parado, despause em Dashboard › Settings › General — os dados continuam lá, nada é perdido.

## Backup

A cota gratuita não faz backup automático. Como o app é offline-first, cada celular já é uma réplica completa — mas isso não substitui um dump. Rode antes de qualquer migration destrutiva:

```bash
supabase db dump -f backup/$(date +%F).sql --data-only
```

Adicione `backup/` ao `.gitignore`: é dado financeiro real, não vai para repositório nenhum.
