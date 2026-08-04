# 00 — Visão de Produto

## O problema

Apps de finanças falham por um motivo só: **registrar um gasto dá trabalho demais**. A pessoa instala, usa uma semana, esquece três dias, abre e vê 12 lançamentos atrasados para preencher, sente culpa e desinstala.

Todo o resto do produto — gráficos, orçamentos, metas — não vale nada se o registro não acontecer. Então a decisão fundadora deste app é:

> **Registrar um gasto tem que custar menos esforço que não registrar.**

Meta numérica, tratada como requisito e não como aspiração: **3 toques e menos de 5 segundos** para o caso comum (gasto, valor, categoria). Qualquer feature que atrapalhe isso perde a discussão.

## Para quem

O núcleo é um **casal que quer ver as finanças juntos sem perder autonomia individual**. Cada pessoa tem o dinheiro dela, as contas dela, os gastos dela — e existe uma camada compartilhada, a casa. O app precisa das duas visões ao mesmo tempo:

- **"Quanto *eu* gastei esse mês?"** — visão pessoal, só minhas contas e meus lançamentos.
- **"Quanto *nós* gastamos esse mês?"** — visão da casa, tudo somado.
- **"Como estamos um em relação ao outro?"** — o comparativo: quem ganhou quanto, quem gastou quanto, quem bancou quanto das despesas comuns.

O grupo cresce com o tempo. Um filho adolescente entra depois com permissão reduzida: registra os gastos dele, vê o que é dele, não mexe nas contas dos pais nem vê os salários. Isso é papel (`role`), não um app diferente.

### Personas

**Jesus (owner).** Renda mista: salário CLT fixo mais venda de produtos que ele mesmo fabrica. Quer saber se o mês fechou no azul e quanto a produção artesanal está de fato rendendo depois dos custos.

**Esposa (adult).** CLT com holerite complicado — salário base, adicional de insalubridade, horas extras, DSR, e descontos de INSS, IRRF, vale. O líquido muda todo mês. Ela precisa registrar *o que caiu*, e opcionalmente detalhar *como chegou nesse valor*, sem que o detalhamento seja obrigatório.

**Filho (teen), futuro.** Registra "comprei lanche, 15 reais" e pronto. Vê a mesada e o que sobrou. Não vê mais nada.

## Princípios de design

Ordem importa. Quando dois princípios conflitam, o de cima ganha.

**1. Velocidade acima de completude.** Todo campo além de valor e categoria é opcional. Estabelecimento, observação, forma de pagamento, foto: opcionais, sempre. O app preenche o que der por conta própria e deixa o resto em branco sem reclamar. Um lançamento incompleto vale infinitamente mais que um lançamento que não aconteceu.

**2. Offline é o normal, não a exceção.** A UI lê exclusivamente do SQLite local. Nunca existe spinner esperando rede para mostrar um saldo. Fila de supermercado sem sinal é o ambiente de uso típico, não um caso de borda.

**3. Padrões inteligentes em vez de perguntas.** Data = hoje. Conta = a última que você usou. Membro = você. Categoria = a que você mais usa nesse estabelecimento nesse horário. O app chuta bem e deixa você corrigir com um toque, em vez de perguntar tudo.

**4. Privacidade dentro de casa.** Compartilhar as finanças não é abrir mão de intimidade. Toda conta e todo lançamento tem `visibility`: `household` (todo mundo vê) ou `private` (só você). Presente de aniversário e terapia não precisam entrar no comparativo. O default é `household`, porque o app é sobre transparência — mas a porta existe.

**5. Números não mentem.** Dinheiro é `int` de centavos, em todo lugar, sempre. Saldo nunca é armazenado, é sempre calculado por soma. Nada de valor materializado divergindo entre dois celulares.

**6. Nada de jargão contábil.** "Entradas" e "Saídas", não "créditos" e "débitos". "Contas fixas", não "obrigações recorrentes". A tela mostra R$ 1.234,56 e uma data em português.

## Escopo

### MVP — o que faz o app existir

- Login por e-mail e senha, com biometria para reabrir
- Casa (household) com convite por código, papéis owner/adult/teen/viewer
- Contas: corrente, poupança, dinheiro, cartão de crédito, vale/benefício, investimento
- Categorias com ícone e cor, hierarquia de dois níveis, catálogo brasileiro pré-carregado
- Lançamentos: despesa, receita, transferência entre contas, compra parcelada
- **Entrada rápida** — a tela mais importante do app
- Sincronização automática entre dispositivos, com resolução de conflito
- Dashboard do mês: saldo, entradas, saídas, top categorias
- **Comparativo entre membros** — o diferencial do produto
- Orçamento por categoria, com alerta em 80% e 100%
- Contas fixas e assinaturas, com lembrete antes do vencimento
- Foto do cupom com OCR local preenchendo valor, data e estabelecimento
- Holerite detalhado (opcional, para quem quiser destrinchar o salário)
- Widgets de tela inicial e atalhos de sistema
- Design system com tema personalizável, claro e escuro

### Depois do MVP

- Rateio automático de despesas da casa e acerto de contas entre membros
- Metas de economia com contribuições
- Importação de extrato OFX e CSV
- Exportação em CSV e PDF
- Leitura de QR Code de NFC-e
- Camada de IA (ver [16-ia-futuro.md](16-ia-futuro.md))
- Multi-moeda de verdade
- Versão web pelo mesmo Supabase

### Fora de escopo, decidido

- **Open Banking / conexão com banco.** Exige certificação, custo e sócio regulado. Não cabe em cota gratuita.
- **Investimentos com cotação em tempo real.** Escopo de outro produto.
- **Nota fiscal eletrônica com validação na SEFAZ.** Talvez leitura do QR depois, nunca emissão.
- **Multi-tenant comercial.** É um app de família, não um SaaS.

## O que faz esse app diferente

Três coisas que a concorrência não faz bem:

**Comparativo de casal como cidadão de primeira classe.** A maioria dos apps trata a família como uma carteira única, o que apaga quem ganhou e quem gastou. Aqui cada lançamento tem dono, e a tela de comparativo mostra os dois lado a lado: receita, despesa, saldo, percentual de contribuição nas despesas comuns. É a conversa que casal realmente tem sobre dinheiro, virada em tela.

**Holerite brasileiro de verdade.** Insalubridade, periculosidade, adicional noturno, DSR, INSS, IRRF, vale-transporte. Nenhum app internacional modela isso, e é exatamente o que faz o líquido variar todo mês para quem é CLT no Brasil.

**Registro por atalho de sistema.** Widget na tela inicial e na tela de bloqueio, tile no painel de configurações rápidas, atalho no ícone, Siri. O app é aberto na tela de registro, não na home. Reduzir o registro a um toque a partir do bloqueio é o que separa quem mantém o hábito de quem desiste.
