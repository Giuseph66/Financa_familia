# Glossário

O projeto usa **inglês no código** (tabelas, colunas, classes, arquivos) e **português na interface**. Esta tabela é a correspondência oficial. Use exatamente estes termos dos dois lados — sinônimo inventado no meio do caminho é como o schema e a UI param de conversar.

## Domínio

| Código | Interface | Significa |
|---|---|---|
| `household` | Casa | O grupo familiar. Um usuário pode ter várias |
| `household_member` | Membro | Pessoa dentro de uma casa. Pode não ter login (membro-fantasma) |
| `profile` | Perfil | Dados do usuário, um por conta de login |
| `account` | Conta | Onde o dinheiro fica: corrente, dinheiro, cartão, vale |
| `category` | Categoria | Classificação do gasto ou da entrada |
| `merchant` | Estabelecimento | Onde a compra aconteceu |
| `transaction` | Lançamento | Um registro de dinheiro entrando ou saindo |
| `transaction_split` | Divisão | Fatia de um lançamento, por categoria ou por membro |
| `budget` | Orçamento | Teto de gasto num período |
| `goal` | Meta | Objetivo de economia |
| `recurrence` | Conta fixa | Despesa ou receita que se repete |
| `payslip` | Holerite | Contracheque detalhado |
| `payslip_item` | Rubrica | Uma linha do holerite |
| `receipt` | Recibo | Foto de comprovante |
| `settlement` | Acerto | Quitação entre membros |

## Tipos de lançamento (`kind`)

| Código | Interface | Sinal |
|---|---|---|
| `expense` | Saída / Despesa | negativo |
| `income` | Entrada / Receita | positivo |
| `transfer_out` | Transferência (saída) | negativo |
| `transfer_in` | Transferência (entrada) | positivo |

Na interface use **Entradas** e **Saídas**. Nada de "créditos" e "débitos" — é jargão contábil e afasta.

## Tipos de conta (`type`)

| Código | Interface |
|---|---|
| `checking` | Conta corrente |
| `savings` | Poupança |
| `cash` | Dinheiro |
| `credit_card` | Cartão de crédito |
| `benefit` | Vale (VR/VA) |
| `investment` | Investimento |
| `other` | Outra |

## Papéis (`role`)

| Código | Interface | Pode |
|---|---|---|
| `owner` | Dono | Tudo, inclusive convidar e excluir a casa |
| `adult` | Adulto | Tudo em dados |
| `teen` | Adolescente | Só os próprios lançamentos; sem holerite |
| `viewer` | Visitante | Só leitura |

## Formas de pagamento (`payment_method`)

`pix` Pix · `debit` Débito · `credit` Crédito · `cash` Dinheiro · `boleto` Boleto · `transfer` Transferência · `benefit_card` Vale · `other` Outro

## Termos técnicos

| Termo | Significa |
|---|---|
| **Offline-first** | A interface lê só do SQLite local. Rede nunca bloqueia tela |
| **Outbox** | Fila local de escritas ainda não enviadas ao servidor |
| **Cursor** | Marca de onde o último pull parou |
| **Push / Pull** | Enviar local → servidor / trazer servidor → local |
| **Soft delete** | Marcar `deleted_at` em vez de apagar, para o delete propagar |
| **LWW** | Last-write-wins: em conflito, a última escrita vence |
| **Linha suja** (`is_dirty`) | Alterada localmente e ainda não confirmada pelo servidor |
| **RLS** | Row Level Security — políticas do Postgres que isolam os dados por casa |
| **Membro-fantasma** | Membro sem conta de login, criado para atribuir gastos |
| **Camada zero** | Sugestão de categoria por frequência de estabelecimento, sem IA |

## Convenções de nome

- Tabela: `snake_case`, plural — `transaction_splits`
- Coluna: `snake_case`, singular — `amount_cents`
- Valor monetário: **sempre** com sufixo `_cents`, tipo inteiro
- Data e hora: sufixo `_at`, tipo `timestamptz`, sempre UTC
- Data pura: sufixo `_on`, tipo `date`
- Booleano: prefixo `is_` ou `has_` — `is_reimbursable`
- Chave estrangeira: `<tabela_singular>_id` — `category_id`
- Classe Dart: `PascalCase` — `TransactionRepository`
- Arquivo Dart: `snake_case` — `transaction_repository.dart`
- Provider Riverpod: `camelCase` + `Provider` — `transactionRepositoryProvider`
