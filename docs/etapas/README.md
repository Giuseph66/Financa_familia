# Plano de Execução

19 etapas, em ordem. Cada uma depende das anteriores.

## Como executar

1. Leia a etapa inteira antes de começar.
2. Leia os documentos que ela referencia.
3. Execute as tarefas na ordem listada.
4. Verifique **todos** os itens do `## DoD` rodando comando, não lendo código.
5. Commit: `feat(eXX): <resumo>`.
6. Próxima etapa.

Se um item do DoD falhar, conserte antes de seguir. Se falhar duas vezes pelo mesmo motivo, registre em [../anexos/BLOQUEIOS.md](../anexos/BLOQUEIOS.md) e siga para a próxima tarefa independente dentro da mesma etapa.

## Ordem

| Etapa | Título | Entrega |
|---|---|---|
| [E00](E00-ambiente.md) | Ambiente | Ferramentas instaladas, JDK corrigido |
| [E01](E01-projeto.md) | Esqueleto do projeto | Flutter roda, estrutura de pastas, lint |
| [E02](E02-design-system.md) | Design system | Tokens, temas, componentes, galeria |
| [E03](E03-supabase.md) | Supabase | Migrations aplicadas, **RLS verificada** |
| [E04](E04-auth.md) | Autenticação | Login, cadastro, biometria, sessão |
| [E05](E05-banco-local.md) | Banco local | Drift, tabelas, DAOs |
| [E06](E06-sync.md) | Motor de sync | Push, pull, conflito, realtime |
| [E07](E07-casa-membros.md) | Casa e membros | Onboarding, convite, papéis |
| [E08](E08-contas-categorias.md) | Contas e categorias | CRUD, saldos |
| [E09](E09-entrada-rapida.md) | **Entrada rápida** | 3 toques, 5 segundos |
| [E10](E10-lancamentos.md) | Lançamentos | Extrato, detalhe, transferência, parcelas |
| [E11](E11-dashboard.md) | Dashboard | Tela inicial completa |
| [E12](E12-relatorios.md) | **Comparativo e relatórios** | A tela-assinatura |
| [E13](E13-orcamentos-metas.md) | Orçamentos e metas | Barras, alertas |
| [E14](E14-recorrencias.md) | Recorrências e notificações | Contas fixas, lembretes |
| [E15](E15-holerite.md) | Holerite | Rubricas, totais, relatórios de renda |
| [E16](E16-recibos.md) | Recibos e OCR | Câmera, ML Kit, parser |
| [E17](E17-widgets.md) | Widgets e atalhos | Glance, WidgetKit, tile, Siri |
| [E18](E18-polimento.md) | Polimento e release | Ajustes, testes, build |

## Marcos

**Depois da E09** existe um app usável: dá para registrar gasto e ele sincroniza. Instale no celular e comece a usar de verdade — o feedback de uso real vale mais que as próximas nove etapas planejadas no vácuo.

**Depois da E12** o produto está diferenciado. O comparativo é o que ele tem que os outros não têm.

**Depois da E17** a promessa original está cumprida por inteiro.

## Estimativa

Ordem de grandeza para um agente trabalhando de forma contínua, não prazo com compromisso:

| Bloco | Peso |
|---|---|
| E00–E03 (fundação) | pequeno, mas E03 não pode ser apressada |
| E04–E06 (auth + dados + sync) | **o maior**. A E06 sozinha vale várias das outras |
| E07–E11 (features base) | médio, muito trabalho de UI repetitivo |
| E12–E15 (features de valor) | médio |
| E16–E17 (OCR + widgets) | médio-alto, envolve código nativo |
| E18 (polimento) | sempre maior do que se espera |

Se for preciso cortar escopo, corte E13, E15 e E16 — nessa ordem. **Nunca corte E06 nem E09**: sem sync o app não cumpre o pedido original, e sem entrada rápida ninguém usa o que foi construído.
