# 15 — Holerite

## Por que existe

O caso concreto: a esposa é CLT com adicional de insalubridade, horas extras variáveis e descontos de INSS, IRRF e vale. **O líquido muda todo mês.** Registrar só "caiu R$ 3.240" perde a informação de *por que* caiu isso, e impossibilita responder a pergunta que a pessoa realmente tem: "esse mês veio menos, o que mudou?".

Nenhum app internacional modela isso, porque insalubridade, periculosidade, DSR e adicional noturno não existem fora do Brasil. É o tipo de coisa que só faz sentido construir para o próprio contexto.

## A regra que protege o produto

**É opcional.** Quem quiser só registrar o valor que caiu faz um lançamento de receita normal e nunca abre esta tela. Se o holerite virar caminho obrigatório, ele contradiz o princípio número um do app — velocidade acima de completude — e o produto se estraga.

O ponto de entrada é discreto: no lançamento de receita, um link "detalhar holerite". E em Mais › Holerites, para quem já entendeu o valor.

## Fluxo

```
Mais › Holerites › Novo
┌─────────────────────────────────┐
│ Membro:     [Maria ▾]           │
│ Competência:[Agosto/2026 ▾]     │
│ Tipo:       [Mensal ▾]          │
│ Empregador: [Hospital X]        │
├─────────────────────────────────┤
│ PROVENTOS                    +  │
│ Salário base           3.200,00 │
│ Insalubridade (20%)      264,00 │
│ Horas extras (12h)       340,50 │
│ DSR sobre extras          68,10 │
│                  Bruto  3.872,60│
├─────────────────────────────────┤
│ DESCONTOS                    +  │
│ INSS                     348,53 │
│ IRRF                     112,40 │
│ Vale-transporte          192,00 │
│ Plano de saúde           180,00 │
│               Descontos   832,93│
├─────────────────────────────────┤
│ LÍQUIDO              R$ 3.039,67│
│                                 │
│ ☑ Lançar como receita           │
│    em [Conta Corrente ▾]        │
│ 📷 Anexar contracheque          │
└─────────────────────────────────┘
```

Os totais são recalculados pelo trigger `recalc_payslip_totals` no Postgres e localmente na escrita — não são digitados. Se o líquido não bater com o que caiu na conta, ou uma rubrica está faltando ou foi digitada errada, e o app aponta isso.

## Entrada rápida do holerite

Digitar 8 rubricas por mês é atrito, e atrito mata a feature. Três atalhos:

**Copiar do mês anterior.** Traz todas as rubricas com os valores antigos, e o usuário ajusta só o que mudou (tipicamente horas extras e IRRF). De 8 campos para 2.

**Rubricas frequentes.** O `+` mostra primeiro as rubricas que aquele membro já usou, ordenadas por frequência. Não uma lista de 40 opções em ordem alfabética.

**Foto do contracheque.** O mesmo OCR dos recibos, com um parser diferente: procura pares "descrição … valor" em colunas, e as palavras-chave de rubrica conhecidas. Acerto menor que o do cupom fiscal (layout de contracheque varia muito entre empresas), mas mesmo preencher metade das linhas já vale. O usuário confere e corrige.

## Catálogo de rubricas

Em [anexos/seed-rubricas.md](anexos/seed-rubricas.md). Sugestões, não uma lista fechada — o usuário digita o que quiser.

**Proventos:** Salário base · Horas extras 50% · Horas extras 100% · Adicional noturno · **Adicional de insalubridade** · **Adicional de periculosidade** · DSR sobre variáveis · Comissão · Gratificação · Prêmio · Adicional por tempo de serviço · Salário-família · Férias · 1/3 constitucional de férias · 13º salário · Aviso prévio · Reflexos

**Descontos:** INSS · IRRF · Vale-transporte · Vale-refeição · Vale-alimentação · Plano de saúde · Plano odontológico · Contribuição sindical · Adiantamento salarial · Faltas e atrasos · Empréstimo consignado · Pensão alimentícia · Seguro de vida · Coparticipação

**Informativos:** Base INSS · Base IRRF · Base FGTS · FGTS do mês · Salário-família (informativo)

Insalubridade e periculosidade em destaque porque são o caso concreto da persona, e porque quase nenhum app tem.

## Relatórios que isso habilita

**Evolução da renda** — linha de 12 meses do bruto e do líquido, com 13º e férias destacados. Toggle para excluir não-mensais e ver a linha de base real.

**Composição do salário** — quanto do bruto é salário base e quanto é variável. Uma pessoa com 30% da renda em horas extras tem uma situação financeira bem diferente de quem tem tudo fixo, e ver isso em gráfico muda decisão.

**Carga de descontos** — percentual do bruto que vai embora, e em quê. Muita gente não sabe que perde 25% e se surpreende.

**Comparativo de renda no casal** — alimenta o `income_share_pct` do rateio proporcional em [13](13-relatorios-e-comparativo.md).

## Privacidade

`payslips` é a tabela mais sensível do app. RLS restringe a `owner` e `adult`: `teen` e `viewer` leem **zero** holerites, nem o próprio.

Cônjuges veem o holerite um do outro, e isso é deliberado — é o ponto do produto. Quem não quiser compartilhar simplesmente não cadastra o holerite e registra o líquido como receita comum. A porta de saída existe e não exige configuração.

Holerite nunca aparece em notificação, nem em widget, nem no modo privacidade do dashboard.

## Fora de escopo, e por quê

**Cálculo automático de INSS e IRRF.** As tabelas mudam por lei todo ano, faixas e deduções têm regras de arredondamento próprias, e errar significa mostrar um número errado com cara de autoridade. O app **registra** o que está no contracheque; não recalcula. Se um dia entrar, tem que ser como conferência ("o INSS parece 12 reais acima da tabela de 2026 — confira"), nunca como fonte da verdade.

**Simulação de rescisão e férias.** Escopo de calculadora trabalhista, não de app de controle financeiro.
