# 16 — Camada de IA (futuro)

Nada disto entra no MVP. Está documentado agora porque **algumas decisões de hoje precisam considerar isto**, principalmente a tabela `merchants` e a coluna `transactions.source`.

## Regra: só chame um modelo onde SQL não resolve

A tentação é usar IA para categorizar lançamento. Resistir. A categorização por frequência de estabelecimento — a tabela `merchants` de [02](02-modelo-de-dados.md) — resolve a maior parte dos casos com um `SELECT`, offline, de graça, e com latência zero.

O caminho é em camadas, e cada uma só entra quando a anterior falhar:

| Camada | Como | Custo | Cobertura estimada |
|---|---|---|---|
| 0 | `merchants.default_category_id` | zero | ~70% |
| 1 | Heurística: horário, valor típico, palavras-chave | zero | +15% |
| 2 | Classificador local (regressão sobre histórico) | zero | +5% |
| 3 | Claude via Edge Function | ~US$ 0,001/chamada | os ~10% restantes |

A camada 3 só é acionada quando as anteriores não têm confiança, e o resultado dela **alimenta a camada 0** — a resposta vira `merchants.default_category_id`, e aquele estabelecimento nunca mais precisa de modelo. O custo cai a cada uso.

## Onde IA realmente ganha

Estes são os casos em que não há alternativa barata, e por isso valem a chamada:

### 1. Entrada por texto livre

> "gastei 45 no posto ontem"
> → despesa · R$ 45,00 · Combustível · ontem

Um parser de regex resolve as frases simples (número + preposição + palavra conhecida) e deveria ser tentado primeiro. Mas "paguei 230 do cartão da Maria e 45 de gasolina" já exige compreensão de estrutura, e aí o modelo ganha. Vale especialmente combinado com ditado por voz, que é o modo mais rápido de registrar dirigindo ou carregando sacola.

### 2. Perguntas em linguagem natural

> "quanto gastamos com delivery esse ano?"
> "qual mês eu mais gastei com o carro?"
> "a gente tá gastando mais que ano passado?"

Implementação segura: o modelo **não** escreve SQL. Ele escolhe entre um conjunto fechado de consultas parametrizadas e preenche os parâmetros. Deixar um modelo gerar SQL contra um banco financeiro é convite a injeção e a query acidentalmente destrutiva, mesmo com o usuário sendo o dono dos dados.

```dart
// O modelo devolve isto, não SQL:
{ "query": "spend_by_category",
  "params": { "category": "food.delivery", "from": "2026-01-01", "to": "2026-12-31" } }
```

### 3. Insights mensais

Um parágrafo no fim do mês, com o que mudou e por quê:

> "Agosto fechou com R$ 1.890 sobrando, 23% acima da média. Mercado caiu R$ 300 em relação a julho. Combustível subiu R$ 180 — foram 6 abastecimentos contra 4 no mês passado."

O valor está em conectar fatos que a pessoa não cruzaria sozinha. O que **não** fazer: conselho financeiro. "Você deveria investir" é fora de escopo, potencialmente regulado, e nem sempre correto para a situação de quem lê.

### 4. Leitura de recibo difícil

Quando o OCR local devolve confiança baixa, mandar o texto extraído (não a imagem — texto é ordens de grandeza mais barato) para um modelo estruturar. Só o texto já resolve a maior parte dos cupons amassados.

## Arquitetura

**A chave da API nunca entra no app.** Um APK com chave da Anthropic dentro é uma conta aberta para quem baixar. Tudo passa por Edge Function:

```
App → Edge Function (Deno) → Anthropic API
       └ chave em variável de ambiente do Supabase
       └ verifica o JWT do usuário
       └ limita taxa por usuário
       └ registra uso
```

```ts
// supabase/functions/ai-assist/index.ts
Deno.serve(async (req) => {
  const jwt = req.headers.get('Authorization')?.replace('Bearer ', '');
  const { data: { user } } = await supabase.auth.getUser(jwt);
  if (!user) return new Response('unauthorized', { status: 401 });

  // Limite por usuário. Sem isto, um bug de loop no cliente gera uma
  // fatura desagradável.
  if (await exceededQuota(user.id)) {
    return new Response('quota exceeded', { status: 429 });
  }

  const { task, payload } = await req.json();

  const res = await anthropic.messages.create({
    // Haiku para classificar e extrair: barato, rápido, suficiente
    // para tarefa estruturada. Sonnet só para insights, que é onde a
    // qualidade da escrita aparece.
    model: task === 'insight' ? 'claude-sonnet-5' : 'claude-haiku-4-5-20251001',
    max_tokens: task === 'insight' ? 800 : 300,
    system: SYSTEM_PROMPTS[task],
    messages: [{ role: 'user', content: JSON.stringify(payload) }],
  });

  await logUsage(user.id, task, res.usage);
  return Response.json(extract(res));
});
```

Cota gratuita do Supabase: 500 mil invocações de Edge Function por mês — irrelevante. O custo é o da API da Anthropic, e é ele que precisa de teto.

## Privacidade

Isto não é detalhe. São as finanças de uma família.

**Nada sai do dispositivo sem consentimento explícito.** A camada de IA é desligada por padrão. Ligar exige uma tela que explica, em português claro, o que é enviado, para onde, e o que fica retido.

**Envie o mínimo.** Para categorizar: o nome do estabelecimento e o valor. Não o histórico, não os saldos, não os nomes das pessoas. Para insight mensal: totais agregados por categoria, não a lista de lançamentos.

**Anonimize.** Nomes de membros viram "Membro A" e "Membro B" no que sai. O modelo não precisa saber que é a Maria.

**Nunca envie:** holerite, saldos de conta, nomes reais, CNPJ, chave de NFC-e, imagem de recibo.

**Deixe desligar de vez.** Um interruptor em Ajustes que apaga tudo que foi enviado do cache local e nunca mais chama.

## O que fica de fora, por decisão

**Conselho financeiro.** "Invista", "corte esse gasto", "você pode se endividar". Fora de escopo por três motivos: pode ser regulado, o modelo não conhece a situação real da pessoa, e um conselho errado com cara de autoridade causa dano concreto.

**Previsão de gastos futuros.** Média móvel resolve com honestidade e sem prometer precisão que não existe. Um modelo dizendo "você vai gastar R$ 3.240 em setembro" transmite confiança que o número não tem.

**Detecção de fraude.** Requer dados que o app não tem (localização, padrão do cartão, base de comerciantes) e falso positivo aqui assusta o usuário à toa.

## Preparação já feita no MVP

Três coisas no design atual existem por causa disto:

- **`transactions.source`** com o valor `'ai'` já previsto — dá para medir o que veio de IA e avaliar se acerta.
- **`merchants.default_category_id`** é onde o aprendizado se acumula, com ou sem modelo. É a camada 0 e o destino das respostas da camada 3.
- **`receipts.ocr_text`** guarda o texto bruto, então dá para reprocessar o histórico com um parser melhor depois, sem pedir foto de novo.

Nenhuma dessas custou complexidade. É o tipo de preparação que vale fazer: barata agora, cara de retroagir depois.
