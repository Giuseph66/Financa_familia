# 01 — Arquitetura

## Stack

| Camada | Escolha | Por quê |
|---|---|---|
| UI | Flutter 3.44 / Dart 3.12 | Um código, Android e iOS, e é o único framework cross-platform com caminho decente para widgets nativos de tela inicial |
| Estado | Riverpod 3 (com codegen) | Providers testáveis sem `BuildContext`, `AsyncValue` resolve loading/erro sem boilerplate, e o codegen elimina o erro de digitar nome de provider errado |
| Banco local | Drift (SQLite) | SQL tipado em tempo de compilação, migrations versionadas, `Stream` reativo em cima de query — a UI se atualiza sozinha quando o sync grava |
| Backend | Supabase (Postgres 17) | Postgres relacional espelha o SQLite 1:1, RLS protege no banco e não no app, cota gratuita cobre o caso com folga |
| Navegação | go_router | Deep link (`financa://quick-add`) é requisito por causa dos widgets, e go_router é o único que trata isso sem gambiarra |
| Modelos | Freezed + json_serializable | Imutabilidade, `copyWith`, igualdade estrutural e serialização sem escrever à mão |
| Gráficos | fl_chart | Suficiente, sem dependência nativa, customizável o bastante para respeitar o design system |
| OCR | google_mlkit_text_recognition | Roda **no dispositivo**: grátis, offline, e a foto do cupom não sai do celular |

## As decisões que importam

Estas cinco definem o app. As outras são detalhe.

### 1. Offline-first de verdade: a UI nunca fala com a rede

```
Widget → Riverpod Provider → Repository → Drift (SQLite)
                                            ▲
                                            │ só o SyncEngine escreve daqui
                                            │
                             SyncEngine ⇄ Supabase (PostgREST + Realtime)
```

A regra é absoluta: **nenhum widget, provider ou repositório chama Supabase para ler dado de tela.** A UI observa `Stream` do Drift. O `SyncEngine` roda em background, grava no Drift, e o Drift emite — a tela se atualiza sozinha.

O que isso compra: zero spinner, funcionamento pleno no modo avião, e um único caminho de dados para depurar. O que custa: todo dado precisa existir localmente, e conflito precisa de política explícita. Vale a troca — [07-sync-engine.md](07-sync-engine.md) resolve o custo.

A única exceção é o upload de foto de recibo, que vai direto para o Storage por uma fila própria, porque binário não faz sentido em tabela local.

### 2. IDs gerados no cliente, UUID v7

Nada de `serial` ou autoincrement. Dois celulares offline gerariam o mesmo `1`, e no sync um sobrescreveria o outro.

UUID **v7** e não v4 porque v7 tem timestamp no prefixo e é ordenável. Isso mantém o índice B-tree do Postgres com inserção sequencial em vez de aleatória, e permite ordenar por criação sem coluna extra. O pacote `uuid` gera v7 com `const Uuid().v7()`.

### 3. Soft delete em tudo que sincroniza

Nenhuma linha sincronizável é apagada de verdade. Marca-se `deleted_at`.

O motivo é concreto: se o celular A apaga a linha fisicamente e o celular B esteve offline uma semana, o B nunca fica sabendo do delete — e no próximo push **ressuscita a linha**. Com `deleted_at` o delete é só mais uma atualização e propaga como qualquer outra.

Toda query de leitura filtra `deleted_at IS NULL`. Um job de limpeza remove fisicamente o que está apagado há mais de 90 dias, quando todos os dispositivos já convergiram.

### 4. Dinheiro é `int` de centavos. Sempre.

`amount_cents BIGINT` no Postgres, `IntColumn` no Drift, `int` no Dart, encapsulado num value object `Money`.

Ponto flutuante para dinheiro é bug garantido: `0.1 + 0.2 == 0.30000000000000004`, e num extrato de 300 linhas isso vira centavos de diferença que ninguém consegue explicar. `BIGINT` porque `INT` estoura em R$ 21 milhões e não custa nada evitar.

O sinal **não** fica no valor — `amount_cents` é sempre positivo, e a direção vem do `kind`. Isso evita a classe de bug em que uma despesa é gravada positiva e some do relatório. O Postgres expõe uma coluna gerada `signed_amount_cents` para somar sem `CASE`.

### 5. Saldo é calculado, nunca armazenado

Saldo de conta é `opening_balance_cents + SUM(signed_amount_cents)`. Não existe coluna `balance`.

Saldo materializado é a fonte número um de divergência em app sincronizado: dois dispositivos incrementam o mesmo campo offline, e o último a sincronizar apaga o incremento do outro. Somar é O(n) num n que para uma família é uns poucos milhares de linhas por ano — irrelevante, e com índice em `(account_id, occurred_at)` some no ruído. Se um dia doer, resolve-se com view materializada por mês, não com campo mutável.

## Estrutura de pastas

```
lib/
├── main.dart                     # só bootstrap
├── app/
│   ├── app.dart                  # MaterialApp.router
│   ├── router.dart               # go_router + deep links
│   ├── bootstrap.dart            # init de Supabase, Drift, notificações, timezone
│   └── observers.dart            # ProviderObserver para log
│
├── core/
│   ├── env/env.dart              # lê --dart-define
│   ├── money/                    # Money, formatação pt_BR, parsing
│   ├── date/                     # períodos, ciclo de fatura, mês contábil
│   ├── result/                   # Result<T, Failure>
│   ├── errors/                   # hierarquia de Failure
│   ├── extensions/
│   ├── logging/
│   └── utils/uuid.dart           # newId() → UUID v7
│
├── design_system/
│   ├── tokens/                   # color, spacing, radius, typography, motion, elevation
│   ├── theme/                    # AppTheme, ThemePreset, ThemeExtensions
│   ├── components/               # atoms, molecules, organisms
│   └── gallery/                  # rota /dev/ds — catálogo visual
│
├── data/
│   ├── local/
│   │   ├── database.dart         # AppDatabase (Drift)
│   │   ├── tables/               # uma tabela por arquivo
│   │   ├── daos/                 # um DAO por agregado
│   │   └── migrations/
│   ├── remote/
│   │   ├── supabase_client.dart
│   │   └── endpoints/            # wrapper fino por tabela
│   ├── sync/
│   │   ├── sync_engine.dart
│   │   ├── outbox.dart
│   │   ├── cursor_store.dart
│   │   ├── conflict.dart
│   │   ├── realtime_listener.dart
│   │   └── mappers/              # row local ⇄ json remoto
│   └── repositories/             # implementações
│
├── domain/
│   ├── entities/                 # Freezed, sem dependência de Drift ou Supabase
│   ├── repositories/             # interfaces abstratas
│   └── usecases/                 # só onde há regra de negócio real
│
├── features/
│   ├── auth/ onboarding/ household/
│   ├── dashboard/ quick_add/ transactions/
│   ├── accounts/ categories/ budgets/ goals/
│   ├── recurrences/ payslips/ receipts/
│   ├── reports/ settings/ shortcuts/
│   └── <cada uma: presentation/{screens,widgets,controllers} + providers.dart>
│
└── l10n/                         # ARB, pt_BR base

android/app/src/main/kotlin/.../widget/    # Glance — widgets Android
ios/FinancaWidget/                          # WidgetKit — widgets iOS
supabase/migrations/                        # SQL versionado
test/ · integration_test/
```

### Como as camadas se relacionam

Clean Architecture aplicada com bom senso, não com dogma:

- `domain/` não importa nada de `data/` nem de Flutter. É Dart puro. Testável sem device.
- `data/` implementa as interfaces de `domain/repositories/`.
- `features/` só conhece `domain/` e `design_system/`.
- Onde não existe regra de negócio, o controller chama o repositório direto. **Não crie usecase que só repassa a chamada** — isso é cerimônia sem valor. Usecase existe para coisas como "registrar transferência" (que grava duas linhas atômicas) ou "materializar recorrência vencida".

## Dependências

`pubspec.yaml` — versões conferidas contra Flutter 3.44 / Dart 3.12. O agente deve rodar `flutter pub outdated` e subir para a última compatível antes de fixar.

```yaml
dependencies:
  flutter: {sdk: flutter}
  flutter_localizations: {sdk: flutter}

  # estado e navegação
  flutter_riverpod: ^3.0.0
  riverpod_annotation: ^3.0.0
  go_router: ^17.0.0

  # modelos
  freezed_annotation: ^3.0.0
  json_annotation: ^4.9.0

  # banco local
  drift: ^2.29.0
  drift_flutter: ^0.2.7
  sqlite3_flutter_libs: ^0.5.40

  # backend
  supabase_flutter: ^2.11.0

  # utilidades
  uuid: ^4.5.1
  intl: ^0.20.2
  collection: ^1.19.0
  path_provider: ^2.1.5
  connectivity_plus: ^7.0.0
  shared_preferences: ^2.5.0
  flutter_secure_storage: ^10.0.0
  package_info_plus: ^9.0.0
  device_info_plus: ^12.0.0

  # UI
  fl_chart: ^1.1.0
  dynamic_color: ^1.7.0
  flutter_svg: ^2.2.0
  cached_network_image: ^3.4.1
  flutter_animate: ^4.5.2
  shimmer: ^3.0.0

  # câmera e OCR
  image_picker: ^1.2.0
  google_mlkit_text_recognition: ^0.15.0
  google_mlkit_barcode_scanning: ^0.14.0
  flutter_image_compress: ^2.4.0

  # sistema
  home_widget: ^0.8.0
  quick_actions: ^1.1.0
  flutter_local_notifications: ^19.0.0
  workmanager: ^0.9.0
  local_auth: ^2.3.0
  receive_sharing_intent: ^1.8.1
  timezone: ^0.10.0
  share_plus: ^12.0.0
  url_launcher: ^6.3.1

dev_dependencies:
  flutter_test: {sdk: flutter}
  integration_test: {sdk: flutter}
  build_runner: ^2.5.0
  riverpod_generator: ^3.0.0
  drift_dev: ^2.29.0
  freezed: ^3.0.0
  json_serializable: ^6.9.0
  custom_lint: ^0.7.5
  riverpod_lint: ^3.0.0
  flutter_lints: ^6.0.0
  mocktail: ^1.0.4
  golden_toolkit: ^0.15.0
```

### Nota sobre versões

`flutter pub add` sem constraint pega a última — e para Riverpod 3 e Freezed 3 houve breaking changes em relação às versões 2.x que a maior parte dos tutoriais ainda usa. Em Riverpod 3, `Ref` não é mais genérico (`Ref<T>` virou `Ref`) e `StateProvider` está deprecado em favor de `Notifier`. Em Freezed 3, classes precisam de `sealed` ou `abstract`. Se o codegen reclamar, é isso — não é bug de instalação.

## Configuração obrigatória

### `analysis_options.yaml`

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  plugins: [custom_lint]
  exclude: ['**/*.g.dart', '**/*.freezed.dart', 'lib/l10n/**']
  errors:
    invalid_annotation_target: ignore
    missing_required_param: error
    missing_return: error

linter:
  rules:
    prefer_const_constructors: true
    prefer_final_locals: true
    always_declare_return_types: true
    avoid_print: true
    require_trailing_commas: true
    unawaited_futures: true
```

### Gradle e o JDK 25

O sistema tem JDK 25 como padrão. O Gradle usado pelo Flutter 3.44 **não suporta JDK 25** e falha com `Unsupported class file major version 69`. O JDK 21 já está instalado.

Em `android/gradle.properties`, adicione:

```properties
org.gradle.java.home=/usr/lib/jvm/java-21-openjdk-amd64
org.gradle.jvmargs=-Xmx4G -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.enableJetifier=false
```

Isso fixa o JDK só para este projeto, sem mexer no `update-alternatives` do sistema.

### `android/app/build.gradle.kts`

```kotlin
android {
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true   // exigido por flutter_local_notifications
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    defaultConfig {
        applicationId = "br.com.neurelix.financa"
        minSdk = 26        // Glance widgets + ML Kit
        targetSdk = 36
        multiDexEnabled = true
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
```

`minSdk 26` (Android 8.0) é deliberado: Glance precisa de 23+, ML Kit de 21+, e notificação agendada exata funciona melhor de 26 pra cima. Cobre praticamente todo aparelho em uso.

### iOS

`ios/Podfile`: `platform :ios, '15.0'`. Necessário para WidgetKit com Lock Screen widgets (16+ para os acessórios, mas 15 é o piso do supabase_flutter). Widgets de tela de bloqueio ficam condicionados a `@available(iOS 16.0, *)`.

## Fluxo de dados, exemplo completo

Usuário registra R$ 32,90 no mercado, sem internet:

1. `QuickAddController.save()` monta uma `Transaction` com `id = newId()` (UUID v7) e `updatedAt = now()`.
2. `TransactionRepository.upsert()` grava no Drift **e** enfileira na tabela `outbox` — na mesma transação SQLite, para não existir estado em que gravou mas não enfileirou.
3. O Drift emite no `Stream`. Dashboard, lista e saldo atualizam. **Tempo total: milissegundos. Nenhuma rede envolvida.**
4. `SyncEngine` percebe que há outbox pendente. Sem conectividade, agenda retry com backoff exponencial.
5. Volta o sinal. `connectivity_plus` dispara o engine.
6. Engine faz push: `upsert` no PostgREST, respeitando ordem de dependência de FK.
7. Sucesso → remove da outbox, grava `remote_synced_at`.
8. Engine faz pull: `sync_pull(household, cursor)` traz o que mudou no servidor.
9. No celular da esposa, o canal Realtime avisa; ela puxa e vê o lançamento em segundos.

Se o passo 6 falhar por conflito, [07-sync-engine.md](07-sync-engine.md) define exatamente quem ganha.
