# E04 — Autenticação

Referências: [03-supabase-setup.md](../03-supabase-setup.md), [09-navegacao-e-telas.md](../09-navegacao-e-telas.md), [05-rls-seguranca.md](../05-rls-seguranca.md#segurança-no-dispositivo)

## Tarefas

### 1. Inicialização do Supabase

Em `bootstrap.dart`:

```dart
await Supabase.initialize(
  url: Env.supabaseUrl,
  anonKey: Env.supabaseAnonKey,
  authOptions: const FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce,
    localStorage: SecureLocalStorage(),
  ),
  realtimeClientOptions: const RealtimeClientOptions(
    logLevel: RealtimeLogLevel.error,
  ),
);
```

PKCE em vez do fluxo implícito porque o token não passa pela URL de redirect, onde outro app registrado no mesmo esquema poderia capturá-lo.

`SecureLocalStorage` usa Keychain no iOS e EncryptedSharedPreferences no Android. **Token nunca em `SharedPreferences` puro.**

### 2. Telas

`lib/features/auth/presentation/screens/`:

- `welcome_screen.dart` — logo, "Entrar", "Criar conta"
- `login_screen.dart` — e-mail, senha, "Esqueci a senha"
- `signup_screen.dart` — nome, e-mail, senha com indicador de força
- `forgot_password_screen.dart`
- `lock_screen.dart` — biometria

Tudo com os componentes de [E02](E02-design-system.md). Nenhum widget novo de formulário aqui.

### 3. Controller

```dart
@riverpod
class AuthController extends _$AuthController {
  @override
  Stream<AuthState> build() =>
      Supabase.instance.client.auth.onAuthStateChange;

  Future<Result<void>> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        // Lido pelo trigger handle_new_user para nomear o perfil e a
        // casa pessoal. Sem isto, o nome vira a parte do e-mail antes
        // do @.
        data: {'display_name': displayName},
      );
      return const Ok(null);
    } on AuthException catch (e) {
      return Err(_translate(e));
    }
  }
}
```

### 4. Mensagens de erro em português

O Supabase devolve em inglês. Traduza no controller, sem vazar detalhe técnico:

| Original | Exibido |
|---|---|
| `Invalid login credentials` | E-mail ou senha incorretos |
| `User already registered` | Este e-mail já tem conta. Entrar? |
| `Email not confirmed` | Confirme seu e-mail. Reenviar? |
| `Password should be at least 6 characters` | A senha precisa de pelo menos 8 caracteres |
| falha de rede | Sem conexão. Tente de novo. |

**Nunca diferencie "e-mail não existe" de "senha errada"** na mensagem. Isso permite enumerar quem tem conta no app.

### 5. Redirect do router

```dart
String? _authRedirect(BuildContext c, GoRouterState s) {
  final session = Supabase.instance.client.auth.currentSession;
  final loggedIn = session != null;
  final atAuth = ['/welcome','/login','/signup','/forgot'].contains(s.matchedLocation);

  if (!loggedIn && !atAuth) return '/welcome';
  if (loggedIn && atAuth) return '/';
  if (loggedIn && _needsLock()) return '/lock';
  return null;
}
```

### 6. Biometria

```dart
class BiometricGate {
  static const _timeout = Duration(seconds: 60);

  /// Só pede biometria se o app ficou em background além do timeout.
  /// Pedir a cada volta, mesmo depois de 2 segundos, faz o usuário
  /// desligar o recurso — e aí não há proteção nenhuma.
  bool needsAuth(DateTime? backgroundedAt) =>
      _enabled &&
      backgroundedAt != null &&
      DateTime.now().difference(backgroundedAt) > _timeout;

  Future<bool> authenticate() => LocalAuthentication().authenticate(
        localizedReason: 'Desbloqueie para ver suas finanças',
        options: const AuthenticationOptions(
          biometricOnly: false,   // permite PIN do aparelho como alternativa;
                                  // digital falha e o usuário não pode ficar
                                  // trancado fora dos próprios dados
          stickyAuth: true,
        ),
      );
}
```

Ligada por padrão em aparelho que tem biometria configurada, desligável em Ajustes › Segurança.

### 7. Registro do dispositivo

Após o login, faça upsert em `devices` com plataforma, modelo e versão do app. Alimenta a tela "dispositivos conectados" e, depois, o push.

## DoD

- [ ] Criar conta funciona; o trigger gera perfil, casa e ~70 categorias
- [ ] Login e logout funcionam
- [ ] Sessão persiste ao fechar e reabrir o app
- [ ] Sessão fica em armazenamento seguro, não em `SharedPreferences`
- [ ] Recuperação de senha envia e-mail e o deep link volta para o app
- [ ] Erros aparecem em português, sem termo técnico
- [ ] Mensagem de login inválido não revela se o e-mail existe
- [ ] Biometria bloqueia após 60s em background e desbloqueia com PIN se a digital falhar
- [ ] Sem sessão, qualquer rota redireciona para `/welcome`
- [ ] `devices` recebe o registro após o login

Commit: `feat(e04): autenticação e bloqueio biométrico`
