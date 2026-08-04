# E18 — Polimento e Release

Referências: [17-testes.md](../17-testes.md), [18-build-e-release.md](../18-build-e-release.md)

Sempre maior do que se espera. Reserve tempo de verdade.

## Tarefas

### 1. Ajustes completos

`/more/settings`:

- **Aparência** — preset, cor semente, claro/escuro/sistema, Material You, densidade, escala de fonte, cantos, mostrar centavos, modo daltônico
- **Segurança** — biometria, tempo de bloqueio, esconder valores por padrão, bloquear captura de tela
- **Notificações** — cada tipo, com prévia do que faz
- **Sincronização** — última sincronização, pendentes, conflitos, sincronizar agora, só Wi-Fi para fotos, recriar banco local
- **Atalhos** — configuração dos widgets
- **Casa** — nome, moeda, dia de início do mês, membros
- **Dados** — exportar CSV, apagar conta
- **Sobre** — versão, licenças, política de privacidade

### 2. Apagar conta

Exigido pelas duas lojas. Precisa realmente apagar: `auth.users` em cascata leva perfil e casas onde a pessoa é a única dona.

Confirmação em dois passos, com aviso claro do que se perde. Se a pessoa é `owner` de uma casa com outros membros, ofereça transferir a propriedade antes.

### 3. Estados vazios

Toda lista precisa do seu, com ilustração e ação de saída. É a primeira coisa que o usuário novo vê, e a que mais recebe reclamação quando falta.

### 4. Tratamento de erro

Nenhuma tela pode mostrar exceção crua. Toda falha vira mensagem em português com ação de recuperação.

Tela de erro global com "Tentar de novo" e "Reportar problema".

### 5. Desempenho

Perfil com DevTools:

- Dashboard abre em menos de 300ms com 5.000 lançamentos
- Rolagem do extrato a 60fps
- Sem jank ao trocar de mês
- Uso de memória estável depois de 20 capturas de recibo

Onde tipicamente aparece problema: agregação em Dart em vez de SQL, `setState` em widget grande, imagem sem cache, `ListView` sem `itemExtent`.

### 6. Acessibilidade

- Leitor de tela em todas as telas principais
- `Semantics` em todo gráfico
- Contraste conferido em todos os temas
- Alvos de toque de 48dp
- Escala de fonte até 200%
- `disableAnimations` respeitado

### 7. Textos

Revisão de português em tudo. Sem jargão contábil: "Entradas" e "Saídas", não "créditos" e "débitos".

Verifique o tom no comparativo e no acerto: nenhuma frase pode soar como julgamento ou cobrança.

### 8. Ícone e splash

`flutter_launcher_icons` e `flutter_native_splash`. Ícone adaptativo no Android, todos os tamanhos no iOS.

### 9. Bateria de testes

```bash
flutter analyze                # zero issues
dart run custom_lint           # zero issues
flutter test                   # tudo verde
flutter test integration_test/ # em device real
supabase test db               # RLS
```

### 10. Testes manuais

Em aparelho real, os dois:

- [ ] Modo avião: 5 lançamentos, restaurar rede, conferir que os 5 chegaram
- [ ] Dois aparelhos: lançar em um, aparecer no outro em menos de 10s
- [ ] Widget atualiza depois do lançamento
- [ ] Foto de cupom real do mercado
- [ ] Tema escuro em todas as telas
- [ ] Fonte em 200%
- [ ] Aparelho de 320dp de largura
- [ ] Biometria bloqueia e desbloqueia
- [ ] Fluxo completo de novo usuário, do zero

### 11. Segurança, revisão final

Checklist inteiro de [05-rls-seguranca.md](../05-rls-seguranca.md#checklist-antes-de-considerar-seguro).

Especialmente:

- [ ] **"Confirm email" religado no Supabase** — foi desligado em dev
- [ ] `git grep -i service_role` sem resultado
- [ ] `git log --all --full-history -- .env` sem resultado
- [ ] Advisors › Security vazio

### 12. Build de release

Flavors, keystore, ofuscação, símbolos de debug — [18-build-e-release.md](../18-build-e-release.md).

> **Guarde o keystore e as senhas em backup fora desta máquina.** Perder o keystore significa nunca mais conseguir atualizar o app publicado. Faça o backup antes do primeiro release, não depois.

### 13. Publicação

Política de privacidade hospedada, data safety form, rótulos de privacidade da App Store, conta de demonstração para o revisor.

Teste interno primeiro, com você e a esposa usando de verdade por algumas semanas antes de qualquer distribuição maior.

## DoD

- [ ] Todas as telas de Ajustes funcionando
- [ ] Apagar conta realmente apaga
- [ ] Toda lista tem estado vazio
- [ ] Nenhuma exceção crua chega à interface
- [ ] Metas de desempenho atingidas
- [ ] Leitor de tela funciona nas telas principais
- [ ] Textos revisados, sem jargão e sem julgamento
- [ ] Ícone e splash nas duas plataformas
- [ ] Toda a bateria automatizada verde
- [ ] Todos os testes manuais feitos em aparelho real
- [ ] Checklist de segurança completo
- [ ] Build de release assinado gerado
- [ ] Símbolos de debug guardados
- [ ] Keystore em backup fora da máquina

Commit: `chore(e18): polimento e preparação de release`
