# E01 — Esqueleto do Projeto

Referências: [01-arquitetura.md](../01-arquitetura.md)

## Tarefas

### 1. Criar o projeto

O diretório já existe e tem conteúdo (`docs/`, `dados-supabase`), então crie no lugar:

```bash
cd ~/Neurelix/Finança
flutter create \
  --org br.com.neurelix \
  --project-name financa \
  --platforms android,ios \
  --empty \
  .
```

`--empty` evita o app de contador de exemplo, que só daria trabalho para apagar.

Confira que `docs/` sobreviveu: `ls docs/`.

### 2. Dependências

A lista completa com versões está em [01-arquitetura.md](../01-arquitetura.md#dependências). Cole no `pubspec.yaml` e rode:

```bash
flutter pub get
flutter pub outdated
```

Suba o que estiver desatualizado e for compatível. Atenção a duas quebras que confundem, porque a maior parte dos tutoriais na internet ainda usa as versões antigas:

- **Riverpod 3**: `Ref` não é mais genérico (`Ref<T>` virou `Ref`), e `StateProvider` está depreciado em favor de `Notifier`.
- **Freezed 3**: classes precisam de `sealed` ou `abstract`.

Se o codegen reclamar disso, é a versão nova, não instalação quebrada.

### 3. `.gitignore` completo

```gitignore
# Flutter
.dart_tool/
.packages
build/
*.iml
.flutter-plugins
.flutter-plugins-dependencies

# Codegen — regenerado por build_runner em todo clone
**/*.g.dart
**/*.freezed.dart
**/*.gr.dart
lib/l10n/generated/

# Segredos
.env*
!.env.example
dados-supabase
*.keystore
*.jks
key.properties
android/local.properties
ios/Runner/GoogleService-Info.plist
backup/

# Sistema
.DS_Store
.idea/
.vscode/
```

### 4. Estrutura de pastas

Crie a árvore de [01-arquitetura.md](../01-arquitetura.md#estrutura-de-pastas). Em cada pasta que ainda não terá código, deixe um `.gitkeep`.

### 5. Configuração do Android

`android/gradle.properties`:

```properties
org.gradle.java.home=/usr/lib/jvm/java-21-openjdk-amd64
org.gradle.jvmargs=-Xmx4G -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.enableJetifier=false
```

`android/app/build.gradle.kts` — `minSdk 26`, `compileSdk 36`, desugaring ligado, flavors `dev`/`prod`. Blocos completos em [01-arquitetura.md](../01-arquitetura.md#configuração-obrigatória) e [18-build-e-release.md](../18-build-e-release.md#flavors).

`ios/Podfile`: `platform :ios, '15.0'`.

### 6. Lint

`analysis_options.yaml` conforme [01-arquitetura.md](../01-arquitetura.md#analysis_optionsyaml).

### 7. Núcleo mínimo

Só o suficiente para o app subir:

- `lib/core/env/env.dart` — leitura das variáveis, com `assertConfigured()`
- `lib/core/utils/uuid.dart` — `String newId() => const Uuid().v7();`
- `lib/core/money/money.dart` — o value object, com `+`, `-`, `*`, `split(n)`, `formatted`, `parse`
- `lib/core/result/result.dart` — `sealed class Result<T>` com `Ok` e `Err`
- `lib/app/bootstrap.dart` — inicializa Flutter binding, `Env.assertConfigured()`, `Supabase.initialize`, timezone
- `lib/app/app.dart` — `MaterialApp.router`
- `lib/app/router.dart` — só `/` com uma tela vazia, por enquanto
- `lib/main.dart` — chama `bootstrap()` e roda

`Money` já nesta etapa porque tudo depois depende dele, e porque é a decisão que não pode ser retroagida: se alguém escrever `double` para valor em algum canto, isso se espalha.

### 8. Localização

`l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_pt.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

`lib/l10n/app_pt.arb` com as primeiras chaves. **Nenhuma string de UI hardcoded a partir daqui** — é muito mais barato fazer certo desde a primeira tela.

### 9. Arquivo de ambiente

```bash
cp dados-supabase .env.dev
```

Edite renomeando as chaves para `SUPABASE_URL` e `SUPABASE_ANON_KEY` (o arquivo original usa os prefixos `NEXT_PUBLIC_`, que são do Next.js), e adicione `APP_ENV=dev`. Crie também `.env.example` com as chaves e valores vazios — esse sim vai para o git.

### 10. Rodar

```bash
flutter run --flavor dev --dart-define-from-file=.env.dev
```

## DoD

- [ ] App abre no dispositivo, tela vazia, sem erro no console
- [ ] `flutter analyze` sem nenhum issue
- [ ] `dart run build_runner build --delete-conflicting-outputs` sem erro
- [ ] Rodar sem `--dart-define-from-file` falha com a mensagem clara de `Env.assertConfigured`
- [ ] Testes de `Money` passando: formatação pt-BR, parse, `split` que soma de volta exato
- [ ] `git status` não mostra `.env.dev` nem `dados-supabase`
- [ ] Estrutura de pastas de `01-arquitetura.md` criada

Commit: `feat(e01): esqueleto do projeto flutter`
