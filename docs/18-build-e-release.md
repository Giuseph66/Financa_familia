# 18 — Build e Release

## Ambiente

Verificado em 2026-08-04, na máquina de desenvolvimento:

```
Flutter 3.44.8 (stable) · Dart 3.12.2      ✓
Android SDK em ~/Android/Sdk                ✓
Node v24.12.0                               ✓
JDK 21 em /usr/lib/jvm/java-21-openjdk-amd64 ✓
JDK 25 — padrão do sistema                  ✗ quebra o Gradle
Supabase CLI                                ✗ instalar
```

### O problema do JDK 25

O Gradle usado pelo Flutter 3.44 não suporta Java 25 e falha com `Unsupported class file major version 69`. Não mexa no `update-alternatives` do sistema — outras ferramentas podem depender do 25. Fixe só neste projeto, em `android/gradle.properties`:

```properties
org.gradle.java.home=/usr/lib/jvm/java-21-openjdk-amd64
```

Confirme com `cd android && ./gradlew -version`, que deve reportar JVM 21.

## Flavors

Dois: `dev` e `prod`. Instaláveis lado a lado, para testar uma versão sem perder a que está em uso.

`android/app/build.gradle.kts`:

```kotlin
flavorDimensions += "env"
productFlavors {
    create("dev") {
        dimension = "env"
        applicationIdSuffix = ".dev"
        versionNameSuffix = "-dev"
        resValue("string", "app_name", "Finança Dev")
    }
    create("prod") {
        dimension = "env"
        resValue("string", "app_name", "Finança")
    }
}
```

```bash
flutter run  --flavor dev  --dart-define-from-file=.env.dev
flutter build appbundle --flavor prod --dart-define-from-file=.env.prod --release
```

## Assinatura

```bash
keytool -genkey -v -keystore ~/keys/financa.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias financa
```

`android/key.properties` — **nunca no git**:

```properties
storeFile=/home/jesus/keys/financa.jks
storePassword=<senha>
keyPassword=<senha>
keyAlias=financa
```

> **Guarde o keystore e as senhas em backup, fora desta máquina.** Perder o keystore significa que você **nunca mais consegue atualizar o app publicado na Play Store** — a única saída é publicar sob outro pacote e pedir para todo mundo reinstalar. Play App Signing mitiga isso (o Google guarda a chave de assinatura final), mas a chave de upload ainda é sua. Faça o backup hoje, não depois do primeiro release.

Confirme que está fora do versionamento:

```bash
git check-ignore -v android/key.properties   # tem que casar com o .gitignore
git log --all --full-history -- '**/key.properties' '**/*.jks'   # vazio
```

## Ofuscação

```bash
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/
```

Guarde `build/symbols/` versionado por número de build — sem ele, o stack trace de um crash em produção vira ruído ilegível.

Ofuscação não protege segredo (não há segredo no app: a chave do Supabase é pública por design, e a RLS é quem protege). Serve para reduzir o tamanho e elevar um pouco o custo de engenharia reversa.

## Tamanho do APK

O ML Kit pesa. Medição esperada:

| Item | Tamanho |
|---|---|
| Flutter base | ~7 MB |
| ML Kit texto + código de barras | ~20 MB |
| Fonte Inter Variable | ~350 KB |
| Ícones e assets | ~1 MB |
| **App bundle, por arquitetura** | **~28 MB** |

App Bundle entrega só a arquitetura do aparelho, então o download real fica em torno de 15 MB. Se precisar cortar: o ML Kit tem variante "unbundled" que baixa o modelo do Google Play Services na primeira utilização — tira 20 MB, ao custo de a primeira leitura exigir rede.

## Publicação

### Play Store

Google Play exige, para app financeiro:

- **Política de privacidade** hospedada e acessível, dizendo o que é coletado e onde fica. O app coleta e armazena dado financeiro no Supabase — isso precisa estar escrito.
- **Data safety form** preenchido com honestidade: coleta dado financeiro, dado de foto (recibos), e-mail. Criptografado em trânsito. O usuário pode pedir exclusão.
- **Categoria Finanças** ativa uma revisão mais rigorosa. Não declare recursos que não existem (o app não conecta a banco nenhum, então nada de "Open Banking" na descrição).
- Sem permissões desnecessárias. Peça câmera só quando o usuário tocar em fotografar recibo, com justificativa na tela.

Fluxo: teste interno (você e a esposa) → teste fechado → produção. A primeira revisão de um app de finanças leva alguns dias.

### App Store

Além do equivalente:

- Rótulos de privacidade no App Store Connect
- Justificativa do uso da câmera no `Info.plist` (`NSCameraUsageDescription`), em português e específica: "Para fotografar comprovantes e preencher o lançamento automaticamente"
- `NSFaceIDUsageDescription` para a biometria
- Conta de demonstração para o revisor, com dados de exemplo — sem isso a revisão é rejeitada por não conseguir entrar

## Versionamento

`pubspec.yaml`: `version: 1.0.0+1`. Semântico antes do `+`, código de build incremental depois. O código de build **nunca diminui** — as duas lojas rejeitam.

## Checklist de release

- [ ] `flutter analyze` sem nenhum issue
- [ ] Todos os testes passando
- [ ] Testes de RLS passando contra produção
- [ ] Confirmação de e-mail **religada** no Supabase
- [ ] Nenhuma `service_role` key no repositório (`git grep -i service_role` vazio)
- [ ] `.env*` nunca commitado
- [ ] Keystore em backup fora da máquina
- [ ] Símbolos de debug guardados
- [ ] Testado em dois aparelhos reais, sincronizando entre si
- [ ] Testado sem rede
- [ ] Widgets funcionando na tela inicial
- [ ] Política de privacidade publicada
- [ ] `versionCode` maior que o do release anterior
- [ ] Dump do banco antes de qualquer migration nova em produção
