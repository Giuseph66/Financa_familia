# Rubricas de Holerite

Sugestões para o seletor de `payslip_items`. **Não é lista fechada** — o usuário digita o que quiser. O seletor mostra primeiro as que aquele membro já usou, ordenadas por frequência.

Referência: [15-holerite.md](../15-holerite.md)

## Proventos (`kind = 'earning'`)

| Rubrica | Referência típica | Nota |
|---|---|---|
| Salário base | — | A rubrica-âncora |
| Horas extras 50% | horas | |
| Horas extras 100% | horas | Domingos e feriados |
| Adicional noturno | horas ou % | 22h–5h |
| **Adicional de insalubridade** | 10%, 20% ou 40% | Sobre o salário mínimo ou o base, conforme o acordo |
| **Adicional de periculosidade** | 30% | Sobre o salário base |
| Adicional de transferência | 25% | |
| Adicional por tempo de serviço | % | Anuênio, biênio, quinquênio |
| DSR sobre variáveis | — | Descanso semanal remunerado incidente sobre extras e comissões |
| Comissão | % ou valor | |
| Gratificação | — | |
| Prêmio / bônus | — | |
| Salário-família | nº de filhos | |
| Férias | dias | |
| 1/3 constitucional de férias | — | |
| 13º salário | 1ª ou 2ª parcela | Use `payslips.kind` para separar |
| Abono pecuniário | dias | Venda de 1/3 das férias |
| Aviso prévio indenizado | — | |
| Reflexos | — | Incidência de variáveis sobre outras verbas |
| Ajuda de custo | — | |
| Diárias de viagem | — | |

Insalubridade e periculosidade estão em destaque porque são o caso concreto da persona e porque quase nenhum app modela.

Elas **não se acumulam**: a lei permite escolher a mais vantajosa, não somar as duas. Se o usuário lançar ambas, vale um aviso não bloqueante — pode haver acordo coletivo específico, e o app registra o que está no papel, não o que ele acha que deveria estar.

## Descontos (`kind = 'deduction'`)

| Rubrica | Referência típica | Nota |
|---|---|---|
| INSS | % da faixa | Progressivo por faixa |
| IRRF | % da faixa | Após dedução de INSS e dependentes |
| Vale-transporte | até 6% do base | Desconto do empregado |
| Vale-refeição | % de coparticipação | |
| Vale-alimentação | % de coparticipação | |
| Plano de saúde | — | |
| Plano odontológico | — | |
| Coparticipação médica | — | |
| Contribuição sindical | — | Opcional desde 2017 |
| Contribuição assistencial | — | |
| Adiantamento salarial | — | O vale do dia 20 |
| Faltas e atrasos | horas ou dias | |
| Empréstimo consignado | parcela | |
| Pensão alimentícia | % ou valor | |
| Seguro de vida | — | |
| Farmácia conveniada | — | |
| Multa de trânsito | — | |

## Informativos (`kind = 'info'`)

Aparecem no holerite mas **não entram na soma**. Sem eles, o usuário tenta conferir e não bate com o papel.

| Rubrica | Nota |
|---|---|
| Base de cálculo do INSS | |
| Base de cálculo do IRRF | |
| Base de cálculo do FGTS | |
| FGTS do mês | Depositado pelo empregador, não descontado |
| Salário-família (informativo) | |
| Número de dependentes | |
| Saldo de banco de horas | |

## Nota sobre cálculo

O app **registra** o que está no contracheque; não recalcula INSS nem IRRF.

As tabelas mudam por lei todo ano, as faixas têm regras próprias de arredondamento, e errar significa exibir um número errado com cara de autoridade. Se um dia entrar cálculo, tem que ser como conferência — "o INSS parece R$ 12 acima da tabela de 2026, confira" — nunca como fonte da verdade.
