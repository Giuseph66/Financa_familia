# E00 — Ambiente

Referências: [18-build-e-release.md](../18-build-e-release.md), [03-supabase-setup.md](../03-supabase-setup.md)

## Situação

Já verificado na máquina:

```
Flutter 3.44.8 · Dart 3.12.2       ✓
Android SDK ~/Android/Sdk           ✓
Node v24.12.0                       ✓
JDK 21 e JDK 25 instalados          ✓  (25 é o padrão e quebra o Gradle)
Supabase CLI                        ✗
```

## Tarefas

### 1. Instalar a Supabase CLI

Sem `npm i -g` — o pacote npm é depreciado e falha em Node 24.

```bash
curl -fsSL https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz \
  | tar -xz -C /tmp
sudo mv /tmp/supabase /usr/local/bin/supabase
supabase --version
```

### 2. Conferir o Flutter

```bash
flutter doctor -v
```

Aceitável ficar em vermelho: Chrome, Linux desktop, Xcode. Tem que estar verde: Flutter, Android toolchain, Android Studio ou command-line tools.

Se aparecer `Android license status unknown`:

```bash
flutter doctor --android-licenses
```

### 3. Docker (opcional, recomendado)

Habilita `supabase start` e `supabase db reset`, que é a única forma de validar migration antes de subir para produção.

```bash
docker --version || echo "sem docker — migrations serão validadas direto no remoto"
```

Sem Docker a E03 ainda funciona, mas com menos rede de proteção. Registre a limitação em [../anexos/BLOQUEIOS.md](../anexos/BLOQUEIOS.md) se for o caso.

### 4. Emulador ou aparelho

```bash
flutter devices
```

Precisa de pelo menos um. Para criar emulador:

```bash
sdkmanager "system-images;android-35;google_apis;x86_64"
avdmanager create avd -n financa -k "system-images;android-35;google_apis;x86_64"
```

Aparelho físico é melhor para este projeto: widgets de tela inicial, biometria e câmera não são testáveis com fidelidade em emulador.

### 5. Git

O diretório ainda não é repositório.

```bash
cd ~/Neurelix/Finança
git init
git branch -M main
```

`.gitignore` na raiz — o arquivo completo está na tarefa 3 da [E01](E01-projeto.md). Crie já com o mínimo, porque `dados-supabase` está na raiz e não deve ser commitado:

```gitignore
.env*
!.env.example
dados-supabase
*.keystore
*.jks
key.properties
backup/
```

## DoD

- [ ] `supabase --version` responde
- [ ] `flutter doctor` sem erro em Flutter nem em Android toolchain
- [ ] `flutter devices` lista pelo menos um dispositivo
- [ ] `git status` funciona na raiz do projeto
- [ ] `git check-ignore -v dados-supabase` casa com uma regra do `.gitignore`
- [ ] `/usr/lib/jvm/java-21-openjdk-amd64/bin/java -version` reporta 21

Commit: `chore(e00): ambiente de desenvolvimento`
