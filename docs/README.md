# Finança — Documentação de Execução

App mobile de controle financeiro **pessoal e familiar**, offline-first, feito em **Flutter + SQLite (Drift) + Supabase**.

Esta pasta é a especificação completa do produto. Ela existe para ser **executada por um agente de IA**, etapa por etapa, sem precisar de decisões de arquitetura durante o caminho — todas as decisões já estão tomadas e justificadas aqui.

---

## Como o agente executor deve usar esta pasta

**Regra 1 — Ordem.** Execute [etapas/](etapas/) em ordem numérica. Cada etapa depende das anteriores. Não pule, não reordene, não faça duas em paralelo.

**Regra 2 — Definition of Done.** Cada etapa termina com um bloco `## DoD`. A etapa só está concluída quando **todos** os itens do DoD passam de verdade, verificados por comando executado, não por leitura de código. Se um item falhar, conserte antes de seguir.

**Regra 3 — Não improvise schema.** Nomes de tabela, coluna, enum e rota estão fixados em [02-modelo-de-dados.md](02-modelo-de-dados.md) e [sql/](sql/). O app inteiro depende deles baterem entre Postgres e SQLite. Se precisar de um campo novo, adicione uma migration nova — nunca edite uma migration já aplicada.

**Regra 4 — Commits.** Um commit por etapa concluída, no formato `feat(etapa-07): contas e categorias`. Nunca commite `.env`, `*.keystore`, `*.jks` ou `lib/core/env/env.g.dart`.

**Regra 5 — Quando travar.** Se um passo falhar duas vezes seguidas pelo mesmo motivo, pare, escreva o erro exato em `docs/anexos/BLOQUEIOS.md` e siga para a próxima tarefa independente. Não invente workaround que mude arquitetura.

**Regra 6 — Idioma.** Código, tabelas, colunas e nomes de arquivo em **inglês**. Texto visível ao usuário em **português do Brasil**, sempre via `lib/l10n/`. Nunca hardcode string de UI em widget.

---

## Índice

### Fundamentos (leia antes de escrever código)
| Doc | Conteúdo |
|---|---|
| [00-visao-produto.md](00-visao-produto.md) | O que é, para quem, princípios de design, escopo MVP vs futuro |
| [01-arquitetura.md](01-arquitetura.md) | Stack, decisões técnicas e o porquê de cada uma, estrutura de pastas, dependências |
| [02-modelo-de-dados.md](02-modelo-de-dados.md) | Todas as entidades, campos, regras de negócio e invariantes |

### Backend
| Doc | Conteúdo |
|---|---|
| [03-supabase-setup.md](03-supabase-setup.md) | Criar projeto, CLI, migrations, Storage, Auth, variáveis de ambiente |
| [04-schema-sql.md](04-schema-sql.md) | Guia das migrations, com o SQL completo em [sql/](sql/) |
| [05-rls-seguranca.md](05-rls-seguranca.md) | Row Level Security, a armadilha da recursão, políticas de Storage, ameaças |

### Cliente
| Doc | Conteúdo |
|---|---|
| [06-banco-local-drift.md](06-banco-local-drift.md) | Schema SQLite espelhado, DAOs, migrations locais |
| [07-sync-engine.md](07-sync-engine.md) | Motor de sincronização: outbox, cursor, LWW, conflitos, realtime |
| [08-design-system.md](08-design-system.md) | Tokens, temas personalizáveis, catálogo de componentes, galeria |
| [09-navegacao-e-telas.md](09-navegacao-e-telas.md) | Mapa completo de telas, rotas, deep links |

### Features
| Doc | Conteúdo |
|---|---|
| [10-entrada-rapida.md](10-entrada-rapida.md) | O coração do app: registrar um gasto em 3 toques |
| [11-recibos-ocr.md](11-recibos-ocr.md) | Foto do cupom, OCR on-device, parser de cupom fiscal brasileiro |
| [12-widgets-e-atalhos.md](12-widgets-e-atalhos.md) | Widgets de tela inicial e bloqueio, Quick Settings, Siri, share target |
| [13-relatorios-e-comparativo.md](13-relatorios-e-comparativo.md) | Dashboard, comparativo entre membros, rateio, orçamentos, exportação |
| [14-recorrencias-e-notificacoes.md](14-recorrencias-e-notificacoes.md) | Contas fixas, assinaturas, alertas, background jobs |
| [15-holerite.md](15-holerite.md) | Salário detalhado: bruto, insalubridade, adicionais, descontos |
| [16-ia-futuro.md](16-ia-futuro.md) | Camadas de inteligência, da heurística grátis ao Claude via Edge Function |

### Qualidade e entrega
| Doc | Conteúdo |
|---|---|
| [17-testes.md](17-testes.md) | Estratégia de testes, o que é obrigatório testar |
| [18-build-e-release.md](18-build-e-release.md) | Flavors, assinatura, Play Store, App Store |

### Execução
| Doc | Conteúdo |
|---|---|
| [etapas/](etapas/) | **As tarefas propriamente ditas.** E00 a E18, em ordem |
| [sql/](sql/) | Migrations prontas para `supabase db push` |
| [sql/testes/](sql/testes/) | Validação do schema num Postgres descartável. **Já executado e passando** |
| [anexos/GLOSSARIO.md](anexos/GLOSSARIO.md) | Correspondência código (inglês) ⇄ interface (português). **Leia antes de nomear qualquer coisa** |
| [anexos/seed-categorias.md](anexos/seed-categorias.md) | O catálogo de categorias e o porquê de cada escolha |
| [anexos/seed-rubricas.md](anexos/seed-rubricas.md) | Rubricas de holerite brasileiras |
| [anexos/BLOQUEIOS.md](anexos/BLOQUEIOS.md) | Registro do que travou e do que ficou pendente |

---

## Contexto do ambiente (verificado em 2026-08-04)

```
Flutter 3.44.8 (stable) · Dart 3.12.2
Android SDK  ~/Android/Sdk  (platform-tools, ndk, emulator ok)
Node v24.12.0
JDK 21 em /usr/lib/jvm/java-21-openjdk-amd64   ← usar este
JDK 25 em /usr/lib/jvm/java-25-openjdk-amd64   ← é o default do sistema, QUEBRA o Gradle
Supabase CLI: NÃO instalado
```

Dois itens a resolver na Etapa 00: instalar a Supabase CLI e apontar o Gradle para o JDK 21.

## Projeto Supabase

Já existe, credenciais em `dados-supabase` na raiz do workspace:

```
URL:  https://skkequjojwmivdmaqczb.supabase.co
Key:  sb_publishable_...  (chave pública de cliente — pode ir no app)
```

A publishable key é feita para ficar no cliente; quem protege os dados é a RLS, não a chave. **A `service_role` key nunca entra no app** — ela ignora RLS por completo. Se em algum momento for preciso uma operação privilegiada, ela vive numa Edge Function.

Detalhes de como carregar isso no build: [03-supabase-setup.md](03-supabase-setup.md).

## Estado do SQL

As migrations em [sql/](sql/) foram **executadas de verdade** contra um Postgres 17 em 2026-08-04, junto com os testes funcionais e de RLS de [sql/testes/](sql/testes/). Todas aplicam limpo e todos os testes passam.

Três bugs apareceram nessa execução e já estão corrigidos — vale conhecê-los, porque são o tipo de coisa que se reintroduz por descuido:

1. `v_credit_card_bill` agrupava por posição (`group by ..., 2`), que aponta para a coluna daquele índice na saída e não para a expressão pretendida.
2. `redeem_invite` checava o esgotamento do convite antes da idempotência, então um toque duplo em "aceitar" devolvia erro para quem já era membro.
3. Faltava `grant usage on sequence sync_version_seq to authenticated`. Como `touch_row()` é trigger comum (roda com o privilégio de quem disparou), isso quebraria **toda** inserção vinda do aplicativo — e só apareceria em runtime, no primeiro lançamento que o usuário tentasse salvar.
