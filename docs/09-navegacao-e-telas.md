# 09 — Navegação e Telas

## Estrutura

Quatro abas fixas e um botão central. Quatro porque cinco já força o usuário a ler os rótulos em vez de reconhecer a posição.

```
┌─────────────────────────────────────────┐
│                                         │
│              conteúdo                   │
│                                         │
├─────────────────────────────────────────┤
│  Início   Extrato   [ + ]   Relat.  Mais│
└─────────────────────────────────────────┘
```

O `[+]` não é aba: é um FAB central que abre a folha de entrada rápida por cima de qualquer tela. Toque longo nele abre um menu radial com Receita, Transferência e Foto do recibo.

## Mapa de rotas

```dart
// lib/app/router.dart
final router = GoRouter(
  initialLocation: '/',
  redirect: _authRedirect,
  routes: [
    // --- fora da casca ---
    GoRoute(path: '/splash',    builder: ...),
    GoRoute(path: '/welcome',   builder: ...),
    GoRoute(path: '/login',     builder: ...),
    GoRoute(path: '/signup',    builder: ...),
    GoRoute(path: '/forgot',    builder: ...),
    GoRoute(path: '/onboarding',builder: ...),
    GoRoute(path: '/join',      builder: ...),   // aceitar convite
    GoRoute(path: '/lock',      builder: ...),   // biometria

    // --- casca com as abas ---
    StatefulShellRoute.indexedStack(
      builder: (c, s, shell) => AppScaffold(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardScreen(), routes: [
            GoRoute(path: 'accounts', builder: ...,  routes: [
              GoRoute(path: ':id', builder: ...),
              GoRoute(path: 'new',  builder: ...),
            ]),
            GoRoute(path: 'net-worth', builder: ...),
          ]),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/transactions', builder: ..., routes: [
            GoRoute(path: ':id',    builder: ...),
            GoRoute(path: 'search', builder: ...),
          ]),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/reports', builder: ..., routes: [
            GoRoute(path: 'comparison', builder: ...),  // ← o diferencial
            GoRoute(path: 'categories', builder: ...),
            GoRoute(path: 'trends',     builder: ...),
            GoRoute(path: 'settlement', builder: ...),
          ]),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/more', builder: ..., routes: [
            GoRoute(path: 'budgets',     builder: ..., routes: [...]),
            GoRoute(path: 'goals',       builder: ..., routes: [...]),
            GoRoute(path: 'recurrences', builder: ..., routes: [...]),
            GoRoute(path: 'payslips',    builder: ..., routes: [...]),
            GoRoute(path: 'categories',  builder: ...),
            GoRoute(path: 'household',   builder: ..., routes: [
              GoRoute(path: 'members', builder: ...),
              GoRoute(path: 'invite',  builder: ...),
            ]),
            GoRoute(path: 'settings', builder: ..., routes: [
              GoRoute(path: 'appearance',   builder: ...),
              GoRoute(path: 'security',     builder: ...),
              GoRoute(path: 'sync',         builder: ...),
              GoRoute(path: 'shortcuts',    builder: ...),
              GoRoute(path: 'diagnostics',  builder: ...),
            ]),
          ]),
        ]),
      ],
    ),

    // --- modais em cima de tudo ---
    GoRoute(path: '/quick-add',  pageBuilder: _sheet(QuickAddScreen.new)),
    GoRoute(path: '/capture',    pageBuilder: _fullscreen(ReceiptCaptureScreen.new)),
    GoRoute(path: '/dev/ds',     builder: (_, __) => const GalleryScreen()),
  ],
);
```

`StatefulShellRoute.indexedStack` preserva o estado de cada aba. Sem isso, sair do extrato para ver um relatório e voltar reinicia a rolagem no topo — irritação pequena que aparece dezenas de vezes por dia.

## Deep links

Os widgets de tela inicial dependem disto. Sem deep link funcionando, o widget não tem o que fazer.

| URI | Efeito |
|---|---|
| `financa://quick-add` | Entrada rápida, despesa |
| `financa://quick-add?kind=income` | Entrada rápida, receita |
| `financa://quick-add?category=<id>` | Já com a categoria escolhida — o widget de categoria favorita |
| `financa://quick-add?amount=3290` | Valor pré-preenchido, em centavos |
| `financa://capture` | Abre a câmera direto |
| `financa://transaction/<id>` | Detalhe de um lançamento (usado pela notificação) |
| `financa://reports/comparison` | Comparativo do mês |
| `financa://join?code=ABCD2345` | Aceita convite — link compartilhável por WhatsApp |

Registro no `AndroidManifest.xml`:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="financa" />
</intent-filter>
```

E em `ios/Runner/Info.plist`, `CFBundleURLSchemes` com `financa`.

**Regra de segurança:** deep link **nunca** executa ação com efeito. `financa://quick-add?amount=5000` abre a tela preenchida; não salva nada. Qualquer app instalado pode disparar um link desses, e um que gravasse direto seria um vetor de injeção de dados.

## As telas que importam

### Dashboard (`/`)

Ordem vertical, e a ordem é a mensagem:

1. **Navegador de mês** — setas e o nome do mês. Deslizar horizontalmente troca o mês.
2. **Saldo do mês, em número grande.** Entradas menos saídas. Toque alterna o modo privacidade.
3. **Duas estatísticas lado a lado** — entradas e saídas, com variação percentual contra o mês anterior.
4. **Comparativo dos membros** — barras horizontais, uma por pessoa, cor do membro. Toque leva ao relatório completo. *Esta é a seção que define o produto; ela vem antes de qualquer gráfico genérico.*
5. **Orçamentos em risco** — só os que passaram do `alert_pct`. Se nenhum, a seção não existe.
6. **Próximas contas** — os próximos 7 dias, com botão "Pagar" que lança com um toque.
7. **Últimos lançamentos** — cinco, com link para o extrato.
8. **Contas e saldos** — carrossel horizontal.

Se a casa tem um membro só, a seção 4 vira "Você × mês passado". Nada de espaço vazio nem de comparativo consigo mesmo em barras.

### Extrato (`/transactions`)

Lista agrupada por dia, cabeçalho pegajoso com a data e o total do dia. Rolagem infinita em páginas de 50.

Cada item mostra: ícone da categoria com a cor dela, descrição (ou o nome da categoria, se não houver), o membro em texto pequeno quando a casa tem mais de um, e o valor à direita com sinal e cor. Clipe se tem recibo; nuvem cortada se ainda não sincronizou.

Deslizar para a esquerda apaga (com desfazer), para a direita duplica. Duplicar existe porque gasto repetido é comum — o mesmo café, a mesma passagem — e duplicar é mais rápido que digitar de novo.

Filtros na barra: mês, membro, conta, categoria, tipo, busca por texto. Filtro aplicado vira chip visível e some com um toque. Filtro invisível é a causa clássica de "sumiram meus lançamentos".

### Comparativo (`/reports/comparison`)

A tela-assinatura. Para cada membro:

- barras lado a lado de receita e despesa;
- saldo individual;
- percentual de contribuição nas despesas comuns;
- as três categorias em que a pessoa mais gastou.

Abaixo, o **acerto**: "Jesus bancou R$ 2.300 das despesas da casa, Maria R$ 1.900. Para dividir igual, Maria transfere R$ 200." Com botão que registra o acerto.

Tom importa aqui. O texto nunca julga — nada de "você gastou mais que ela". Só o fato e a ação. Um app que soa como cobrança vira briga de casal e é desinstalado.

### Detalhe do lançamento (`/transactions/:id`)

Valor grande no topo, com a cor do tipo. Abaixo, campos em lista editável: categoria, conta, membro, data, forma de pagamento, estabelecimento, observação, etiquetas. Foto do recibo, se houver, com toque para ampliar.

Se for parcelado, mostra "3 de 12" e um link para as outras parcelas. Se for transferência, mostra as duas contas e edita as duas pernas juntas.

Edição é inline: toque no campo, muda, salva sozinho. Sem botão "Editar" que troca a tela de modo — dois modos numa tela de detalhe é atrito puro.

## Estados globais

**Sem conexão** — faixa fina no topo, "Offline · N alterações pendentes". Discreta, não bloqueante: o app funciona igual, a faixa é só informação.

**Sincronizando** — barra de progresso indeterminada de 2dp sob a AppBar. Nunca um modal.

**Primeiro uso** — onboarding de três passos: nome da casa, adicionar sua primeira conta com saldo, convidar alguém (pulável). Menos de 60 segundos, e "pular" existe em todos.

**Bloqueio** — tela de biometria cobrindo tudo ao voltar do background depois de 60 segundos. Com opção de senha do dispositivo como alternativa, para quando a digital falha.
