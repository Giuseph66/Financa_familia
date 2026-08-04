# E16 — Recibos e OCR

Referências: [11-recibos-ocr.md](../11-recibos-ocr.md)

## Tarefas

### 1. Dependências nativas

```yaml
google_mlkit_text_recognition: ^0.15.0
google_mlkit_barcode_scanning: ^0.14.0
image_picker: ^1.2.0
flutter_image_compress: ^2.4.0
```

Android: `minSdk 26` já está. O modelo adiciona ~20 MB ao APK.

iOS: o modelo é baixado sob demanda na primeira utilização — **trate esse caso**, porque a primeira leitura pode falhar sem rede.

Permissões: `NSCameraUsageDescription` e `NSPhotoLibraryUsageDescription` no `Info.plist`, em português e específicas. `CAMERA` no `AndroidManifest.xml`.

Peça a permissão **quando o usuário tocar em fotografar**, com justificativa na tela. Nunca no boot.

### 2. Captura

Tela de câmera com moldura guia, botão de galeria e lanterna.

Comprima **depois** do OCR, não antes: compressão agressiva destrói o contraste fino que o reconhecedor precisa em impressão térmica. Rode o ML Kit no original, depois comprima para guardar.

Configuração de captura e compressão em [11-recibos-ocr.md](../11-recibos-ocr.md#captura). Resultado: ~4 MB da câmera viram ~200 KB.

### 3. Extração

```dart
final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
final result = await recognizer.processImage(InputImage.fromFilePath(path));
await recognizer.close();   // SEMPRE. Vazar o recognizer é fonte de
                            // OOM depois de várias capturas.
```

Rode o leitor de código de barras junto: se houver QR de NFC-e, a chave de acesso dele é **muito** mais confiável que ler dígitos de impressão térmica, e ganha do texto.

### 4. Parser

`lib/features/receipts/domain/receipt_parser.dart`. Implementação completa em [11-recibos-ocr.md](../11-recibos-ocr.md#parser-de-cupom-fiscal-brasileiro).

Extrai total, data, CNPJ, estabelecimento e chave de acesso, com uma pontuação de confiança.

Pontos que importam:

- **Total**: procura de baixo para cima (fica no rodapé; varrer de cima acha "TOTAL DE ITENS" antes). Sem rótulo, usa o maior valor monetário e rebaixa a confiança.
- **Conversão para centavos sem passar por `double`.** `"1.234,56"` → remove ponto, remove vírgula, `int.parse`. Parsear moeda em ponto flutuante é como o centavo se perde.
- **Data futura ou de mais de um ano atrás é descartada** — é erro de leitura, não compra antiga.
- **Nome do estabelecimento** vem das primeiras linhas, descartando as que são só número, endereço, ou contêm CNPJ/LTDA/CUPOM.

### 5. Testes do parser

`test/fixtures/receipts/*.txt` com texto já extraído, para o teste não depender do ML Kit.

Cubra: cupom de mercado, comprovante de Pix, nota de posto, recibo com desconto (onde o subtotal é maior que o total), e um cupom com OCR ruim onde o esperado é `null` e não um chute.

### 6. Tela de confirmação

**O usuário sempre confirma.** OCR de cupom térmico amassado erra, e um valor errado salvo em silêncio é pior que nenhum valor: contamina o relatório e a pessoa só descobre no fim do mês.

Confiança acima de 0,65: abre tudo preenchido com um resumo. Abaixo: abre com os campos incertos em destaque e o texto bruto acessível para conferência.

### 7. Persistência

Cria `receipts` com `storage_path = '{household_id}/{receipt_id}.jpg'`.

O `household_id` como **primeira pasta** não é organização estética: é o que a política de Storage usa para autorizar. Gravar em outro formato faz as políticas pararem de proteger.

Enfileira em `upload_queue`, abre a entrada rápida preenchida.

Imagem local em `getApplicationDocumentsDirectory()`, **não** em cache: o sistema apaga cache sem avisar, e um recibo que sumiu antes de subir é dado perdido.

### 8. Visualização

Miniatura de 200px no detalhe do lançamento; toque abre em tela cheia com zoom.

Imagem cheia por URL assinada com validade de 1 hora — o bucket é privado, e é comprovante com CPF e endereço impressos. `cached_network_image` evita rebaixar a mesma foto toda vez.

### 9. Alvo de compartilhamento

`receive_sharing_intent` com o `intent-filter` de [12-widgets-e-atalhos.md](../12-widgets-e-atalhos.md#alvo-de-compartilhamento).

Recebeu o comprovante do Pix no WhatsApp? Compartilha para o Finança, que abre a entrada rápida com a imagem anexada e o OCR já rodando.

### 10. Galeria de recibos

`/more/receipts`: grade de miniaturas, filtro por mês e por "sem lançamento vinculado". Toque permite vincular a um lançamento existente.

## DoD

- [ ] Fotografar cupom extrai texto
- [ ] Valor e data corretos em ≥80% dos cupons de mercado
- [ ] Comprovante de Pix: valor correto em ≥90%
- [ ] Testes do parser passando com todas as amostras
- [ ] Confiança baixa destaca os campos incertos
- [ ] Nunca salva sem confirmação
- [ ] Fluxo inteiro funciona offline, do OCR ao salvar
- [ ] Upload retoma sozinho quando a rede volta
- [ ] Foto local sobrevive à limpeza de cache do sistema
- [ ] 20 capturas seguidas sem crescimento de memória
- [ ] Compartilhar imagem de outro app abre a captura
- [ ] Imagem de outra casa no Storage devolve erro
- [ ] Compressão gera arquivo ≤300 KB

Commit: `feat(e16): captura de recibos com ocr local`
