# Catálogo de Categorias

O SQL executável está em [../sql/0008_seed_categories.sql](../sql/0008_seed_categories.sql). Este documento explica as escolhas.

Copiado para cada casa nova pelo trigger `trg_household_bootstrap`. São ~70 categorias em dois níveis.

## Por que copiar em vez de compartilhar

A alternativa — `household_id NULL` significando "global" — parece mais limpa e cria dois problemas: o pull do sync precisa de um caso especial para linhas sem casa, e o usuário não consegue renomear "Alimentação" para "Rango" sem afetar todo mundo.

Duplicar 70 linhas por casa custa alguns kilobytes e elimina os dois problemas.

Os `key` do template são estáveis e nunca mudam. Renomear um `name` no catálogo afeta só casas criadas depois; casas existentes mantêm o que já copiaram, que é o comportamento desejado.

## Estrutura

**Despesas** (14 grupos): Moradia · Alimentação · Transporte · Saúde · Educação · Lazer · Compras · Cuidado pessoal · Família · Financeiro · Impostos e taxas · Seguros · Doações · Outros gastos

**Receitas** (7 grupos): Salário · Benefícios · Trabalho extra · Renda passiva · Reembolso · Presente recebido · Outras entradas

## Escolhas específicas do Brasil

Estas são as que diferenciam de um catálogo internacional traduzido:

| Categoria | Por quê |
|---|---|
| **Mercado** separado de **Delivery** e **Restaurante** | São comportamentos de gasto diferentes e a pessoa quer ver separado. Juntar tudo em "Alimentação" esconde exatamente o que ela quer descobrir |
| **Uber e 99** com nome próprio | É como a pessoa pensa. "Transporte por aplicativo" é linguagem de relatório corporativo |
| **IPVA e licenciamento** | Despesa anual grande e previsível, que merece rastreamento próprio |
| **IPTU** | Idem |
| **Vale-refeição/alimentação** como receita | VR entra como benefício, não como salário, e o saldo é separado |
| **Benefício do governo** | Bolsa Família, BPC, seguro-desemprego |
| **Produção própria** | Renda de produtos fabricados pelo próprio usuário |
| **Anuidade de cartão** e **Tarifas bancárias** separadas | São as duas coisas que mais surpreendem no extrato |
| **Terapia** separada de **Consultas** | Gasto recorrente, mensal, e muita gente acompanha à parte |
| **Feira e açougue** | Compra fora do supermercado, comum e com padrão de gasto próprio |

**`work.handmade` (Produção própria)** existe por causa de um caso real da persona: venda de produtos que ele mesmo fabrica. Sem categoria própria, isso cai em "Outras entradas" e a pessoa nunca descobre quanto a produção artesanal de fato rende — que é justamente a pergunta que ela tem.

## Ícones e cores

Ícones são nomes do conjunto Material Symbols. Cada grupo tem uma cor, e as subcategorias herdam a do pai — assim o gráfico de rosca fica legível por família mesmo com 40 categorias em uso.

## Manutenção

O usuário pode renomear, mudar ícone e cor, arquivar e criar novas.

Categoria com `is_system = true` pode ser renomeada mas **não apagada** — só arquivada. Apagar quebraria lançamentos históricos que apontam para ela.
