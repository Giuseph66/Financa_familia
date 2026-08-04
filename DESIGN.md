# Finança — sistema visual

## Direção

Aplicativo financeiro familiar com clima de workspace doméstico: reservado,
calmo e factual. Dark é o modo principal. Evitar fintech verde, estética
cripto, neon, gradientes decorativos e parede de cards SaaS.

## Cores

Neutros sem matiz: o azul aparece só no acento de marca. É isso que faz
o acento ser lido como acento em vez de se dissolver no fundo.

| Papel | Dark | Contraste no canvas | Uso |
|---|---|---|---|
| Canvas | `#0A0A0C` | — | fundo da aplicação |
| Superfície | `#131316` | — | conteúdo agrupado, campos |
| Superfície elevada | `#1C1C21` | — | modais e seleção |
| Texto | `#F4F4F6` | 18,0:1 | conteúdo principal |
| Texto secundário | `#A8A8B3` | 8,4:1 | explicações |
| Texto fraco | `#82828E` | 5,2:1 | placeholder e apoio |
| Divisor | `#2C2C33` | — | separação decorativa |
| **Contorno de controle** | `#5C5C66` | 3,0:1 | limite de campo e botão de contorno |
| Marca | `#416F96` | 3,7:1 | preenchimento de ação, foco, ícone |
| **Marca em texto** | `#8FB6D8` | 9,3:1 | link e TextButton |
| Marca suave | `#16202B` | — | fundo de aviso informativo |
| Receita | `#68C991` | 9,8:1 | somente semântica de entrada |
| Despesa | `#F28E86` | 8,5:1 | somente semântica de saída |
| Atenção | `#F2BD67` | 11,5:1 | prazo e atenção factual |

Três regras que não se negociam:

- **Marca em texto é `#8FB6D8`, não `#416F96`.** A cor de marca como
  texto atinge 3,4:1 e reprova no AA. `#416F96` é para preenchimento,
  borda e ícone, onde a exigência é 3:1.
- **Contorno de controle é `#5C5C66`, não o divisor.** Em canvas quase
  preto uma borda discreta o bastante para separar seções fica
  invisível como limite de campo. Campo, botão de contorno e afins usam
  `lineStrong`.
- **Campo não afunda.** Em fundo quase preto não há headroom para
  baixo. O campo sobe um degrau (`surface`) e quem o define é a borda.

Receita/despesa sempre têm sinal e ícone além da cor.

## Tipografia e números

- Fonte do sistema até a Inter ser embarcada.
- Títulos compactos; uma única hierarquia forte por viewport.
- Valores usam algarismos tabulares.
- Texto mínimo 12 px; corpo 14–16 px; suporte a 200% sem perda de acesso.

## Layout

- Escala de espaço: 4, 8, 12, 16, 20, 24, 32, 40.
- Alvos interativos mínimos de 48 dp.
- Mobile: 320–919 px, navegação inferior e um único FAB central.
- Desktop: sidebar de 248 px; conteúdo flexível.
- Conteúdo mobile reserva 100 px no fim para navegação/FAB.
- Cards só agrupam informação; não são decoração universal.

## Comportamento

- Todo controle visível conclui ação ou explica indisponibilidade.
- Casa é um workspace real; “Casa inteira” é filtro explícito.
- Estados: carregando, vazio, sincronizando, erro com retry e sucesso.
- Linguagem factual e sem cobrança.
- Recibo é privado e sempre associado ao prefixo da Casa.
