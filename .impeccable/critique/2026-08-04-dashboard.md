# Crítica Impeccable — Dashboard

## Escopo e método

- Alvo: dashboard Flutter web, em 1280×900 e 390×844.
- Assessment A: duas inspeções visuais independentes, código e documentação.
- Assessment B: detector automatizado indisponível (`bundled detector not found`); inspeção visual concluída, sem overlay persistente.
- Console: um 404 do detector temporário; nenhum warning funcional observado.

## Veredito

AI slop moderado (6/10). A interface é polida e usa linguagem humana, mas ainda se parece com um dashboard financeiro genérico: saldo hero verde, dois cards estatísticos, barras de progresso e uma parede de cards arredondados. Isso conflita com as anti-referências do produto: “fintech verde” e “dashboard SaaS com métrica heroica”.

Nielsen: **21/40 — aceitável, mas inadequado para release sem correções.**

## Prioridades combinadas

1. **P1 — Affordances sem comportamento.** Mês, “Casa inteira”, “Detalhes”, “Pagar”, “Ver tudo” e as abas fora de Início não concluem ações. Conectar fluxos reais ou comunicar indisponibilidade sem parecer botão funcional.
2. **P1 — Dados e sincronização simulados.** Valores, membros e lançamentos são hardcoded; “Tudo salvo” não representa estado real. Substituir por sessão/Supabase e estados salvo, sincronizando, offline com pendências e erro com retry.
3. **P1 — Comparativo inconsistente.** Os valores dos membros não fecham com o total usado nas barras. Normalizar a escala, mostrar percentuais e permitir abrir o relatório/acerto.
4. **P1 — Estrutura visual genérica.** Reduzir shells idênticos e verde dominante. Priorizar decisões familiares: lançar, filtrar a casa e entender contribuições.
5. **P1 — Acessibilidade incompleta.** Adicionar semântica a barras e navegação mobile, garantir alvos de 48 dp, teclado, 320 dp e escala de texto 200%.
6. **P2 — Mobile.** Remover ação primária duplicada e reservar inset inferior para barra/FAB.
7. **P2 — Tom impreciso.** Trocar “Dentro do ritmo” e “Pede cuidado” por fatos e critérios explícitos, sem julgamento.
8. **P2 — Entrada rápida enganosa.** Conta/data/membro parecem interativos, mas não são. Corrigir “00”, propagar tipo do lançamento, oferecer imagem/recibo e categorias reais/customizáveis.

## Carga cognitiva

Falha em 5 de 8 critérios: foco único, chunking, uma decisão por vez, escolhas mínimas e divulgação progressiva. O primeiro viewport deve conter contexto (mês/casa), resumo curto e uma ação primária. Conteúdo secundário deve ser progressivo.

## Personas

- Power user: precisa de rotas reais, filtros, duplicação, desfazer e atalhos.
- Acessibilidade: relações entre nome, valor e percentual precisam ser anunciadas; cor nunca é o único sinal.
- Mobile distraído: contexto deve sobreviver a reload; ação primária única, conteúdo protegido da barra fixa.
- Casa compartilhada: deixar explícito o que é da casa, individual ou privado; texto factual, nunca comparativo julgador.

## Direção aprovada pelo pedido

O usuário já definiu o rumo: tema dark discreto, identidade de família/workspace, login, Casa funcional, Supabase, categorias automáticas/customizadas, recibos e teste multiusuário. Portanto a etapa de priorização foi incorporada diretamente ao plano de correção.
