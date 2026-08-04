# Bloqueios e Pendências

Registro do agente executor. Anote aqui o que travou duas vezes pelo mesmo motivo, e o que ficou pendente para depois.

Formato: uma entrada por item, com data, etapa, o erro **exato** (copiado, não parafraseado) e o que foi tentado.

---

## Pendências conhecidas

### `Confirm email` desligado no Supabase

**Etapa:** E03
**Situação:** aberta

Durante o desenvolvimento, a confirmação de e-mail fica desligada em Dashboard › Authentication › Providers › Email, para não depender de caixa de entrada a cada teste.

**Precisa ser religada antes de qualquer usuário real.** Sem confirmação, qualquer pessoa cria conta com o e-mail de outra.

Fechar em: [E18](../etapas/E18-polimento.md), item 11.

---

## Bloqueios

*(vazio — nenhum bloqueio registrado ainda)*

### Modelo de entrada

```
### <título curto do problema>

**Data:** AAAA-MM-DD
**Etapa:** EXX
**Situação:** aberta | contornada | resolvida

**Erro exato:**
​```
<colar a saída literal, sem editar>
​```

**Tentativas:**
1. ...
2. ...

**Contorno adotado:** ...
**O que falta para resolver de vez:** ...
```
