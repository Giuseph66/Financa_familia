# 11 — Recibos e OCR

## Decisão: OCR no dispositivo

`google_mlkit_text_recognition` roda **local**, e essa escolha compra três coisas de uma vez: é grátis (não consome cota nem chamada de API), funciona offline (o cupom é fotografado dentro do mercado, onde o sinal é ruim), e a foto do cupom não sai do celular até o usuário decidir salvar.

O modelo do ML Kit adiciona cerca de 20 MB ao APK no Android. Em iOS ele é baixado sob demanda na primeira utilização — trate esse caso, porque a primeira leitura pode falhar sem rede.

Alternativas descartadas: Google Cloud Vision (custa e exige rede), Tesseract via FFI (qualidade pior em cupom térmico e binário grande), enviar a imagem para um modelo de visão (caro por foto, lento, e desnecessário — o texto do cupom é impresso, não manuscrito).

## O fluxo

```
Câmera → comprime → ML Kit extrai texto → parser heurístico
   → preenche a entrada rápida → USUÁRIO CONFIRMA → salva
   → fila de upload → Storage
```

**O usuário sempre confirma.** OCR de cupom térmico amassado erra, e um valor errado salvo em silêncio é pior que nenhum valor: contamina o relatório e a pessoa só descobre no fim do mês. A tela mostra o que entendeu, com os campos incertos destacados.

## Captura

```dart
final xfile = await ImagePicker().pickImage(
  source: ImageSource.camera,
  imageQuality: 88,
  maxWidth: 1600,     // acima disso o OCR não melhora e o arquivo dobra
);

final compressed = await FlutterImageCompress.compressAndGetFile(
  xfile.path, targetPath,
  quality: 80, minWidth: 1200, minHeight: 1200,
  format: CompressFormat.jpeg,
);
// ~4 MB da câmera vira ~200 KB. Com 1 GB de cota gratuita, isso é
// espaço para cerca de 5.000 comprovantes.
```

**Comprima depois do OCR, não antes.** Compressão agressiva destrói exatamente o contraste fino que o reconhecedor precisa em impressão térmica. Rode o ML Kit no arquivo original e só então comprima para armazenar.

## Extração

```dart
final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
final result = await recognizer.processImage(InputImage.fromFilePath(originalPath));
final text = result.text;
await recognizer.close();   // libera o modelo nativo; vazar isto é
                            // fonte de OOM depois de várias capturas
```

## Parser de cupom fiscal brasileiro

Genérico não funciona. Cupom brasileiro tem estrutura reconhecível, e explorá-la é o que faz a diferença entre 40% e 85% de acerto.

```dart
// lib/features/receipts/domain/receipt_parser.dart
class ReceiptParser {
  ParsedReceipt parse(String raw) {
    final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return ParsedReceipt(
      totalCents: _findTotal(lines),
      date:       _findDate(raw),
      cnpj:       _findCnpj(raw),
      merchant:   _findMerchant(lines),
      accessKey:  _findAccessKey(raw),
      confidence: _score(...),
    );
  }
```

### Total

O campo mais difícil, porque o cupom tem vários números grandes: subtotal, desconto, troco, valor pago, e o total propriamente dito.

```dart
  int? _findTotal(List<String> lines) {
    // "VALOR TOTAL R$", "TOTAL R$", "VL TOTAL". Alguns cupons quebram
    // a linha entre o rótulo e o número, daí o (?:\s|\n)*.
    final labeled = RegExp(
      r'(?:VALOR\s+)?TOTAL(?:\s+A\s+PAGAR)?(?:\s+R\$)?(?:\s|\n)*([\d.]+,\d{2})',
      caseSensitive: false,
    );

    // Procura de baixo para cima: o total fica no rodapé, e varrer de
    // cima acha "TOTAL DE ITENS" antes.
    for (final line in lines.reversed) {
      final m = labeled.firstMatch(line);
      if (m != null) return _toCents(m.group(1)!);
    }

    // Sem rótulo: o maior valor monetário do cupom é o total em quase
    // todo caso — itens individuais são menores por construção.
    // Heurística fraca; rebaixa a confiança e a UI destaca o campo.
    final all = RegExp(r'(\d{1,3}(?:\.\d{3})*,\d{2})')
        .allMatches(lines.join('\n'))
        .map((m) => _toCents(m.group(1)!))
        .toList();
    return all.isEmpty ? null : all.reduce(max);
  }

  /// "1.234,56" → 123456. Nunca passa por double: parsear moeda em
  /// ponto flutuante é como o centavo se perde.
  int _toCents(String s) =>
      int.parse(s.replaceAll('.', '').replaceAll(',', ''));
```

### Data, CNPJ, chave de acesso

```dart
  DateTime? _findDate(String raw) {
    final m = RegExp(r'(\d{2})/(\d{2})/(\d{4})').firstMatch(raw)
           ?? RegExp(r'(\d{2})/(\d{2})/(\d{2})(?!\d)').firstMatch(raw);
    if (m == null) return null;
    var year = int.parse(m.group(3)!);
    if (year < 100) year += 2000;
    final d = DateTime(year, int.parse(m.group(2)!), int.parse(m.group(1)!));
    // Cupom com data futura ou de mais de um ano atrás é erro de
    // leitura, não compra antiga. Descartar é melhor que gravar lixo.
    final now = DateTime.now();
    if (d.isAfter(now.add(const Duration(days: 1)))) return null;
    if (d.isBefore(now.subtract(const Duration(days: 365)))) return null;
    return d;
  }

  String? _findCnpj(String raw) =>
      RegExp(r'\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}').firstMatch(raw)?.group(0);

  /// Chave da NFC-e: 44 dígitos, às vezes agrupados de 4 em 4.
  /// Guardar hoje habilita consulta à SEFAZ depois, sem precisar da
  /// foto de novo.
  String? _findAccessKey(String raw) {
    final compact = raw.replaceAll(RegExp(r'[\s.]'), '');
    return RegExp(r'\d{44}').firstMatch(compact)?.group(0);
  }
```

### Estabelecimento

```dart
  String? _findMerchant(List<String> lines) {
    // O nome fica nas primeiras linhas, antes do CNPJ. Descarta linha
    // que é só número, endereço ou razão social genérica.
    for (final line in lines.take(6)) {
      if (line.length < 3) continue;
      if (RegExp(r'^[\d\s./,-]+$').hasMatch(line)) continue;
      if (RegExp(r'CNPJ|CPF|INSCR|RUA|AV\.|AVENIDA|CEP|LTDA|ME$|EPP',
                 caseSensitive: false).hasMatch(line)) continue;
      if (RegExp(r'CUPOM|FISCAL|DANFE|NFC-?E|EXTRATO',
                 caseSensitive: false).hasMatch(line)) continue;
      return _titleCase(line);
    }
    return null;
  }
```

### Confiança

```dart
  double _score(ParsedReceipt r) {
    var s = 0.0;
    if (r.totalCents != null) s += 0.45;   // o campo que mais importa
    if (r.date != null)       s += 0.20;
    if (r.merchant != null)   s += 0.20;
    if (r.cnpj != null)       s += 0.10;   // achou CNPJ = leu bem
    if (r.accessKey != null)  s += 0.05;
    return s;
  }
```

Acima de 0,65, a tela abre com tudo preenchido e um resumo. Abaixo, abre com os campos incertos em destaque e o texto bruto acessível para conferência manual.

## QR Code

Cupons modernos trazem QR da NFC-e. `google_mlkit_barcode_scanning` roda junto com o texto e, quando encontra, a URL contém a chave de acesso — **muito** mais confiável que ler dígitos de impressão térmica. Se houver QR, ele ganha do texto.

Consultar a SEFAZ para obter o cupom completo (itens, valores, CNPJ) é possível e fica para depois do MVP: cada estado tem endpoint próprio e alguns exigem captcha. A chave fica guardada desde já, então quando isso for implementado o histórico existente já é aproveitável.

## Vinculação com o lançamento

```dart
// 1. Cria o recibo em estado local
final receiptId = newId();
await receiptDao.insert(ReceiptsCompanion.insert(
  id: receiptId,
  householdId: household,
  uploadedBy: userId,
  // O household_id como PRIMEIRA pasta não é organização: é o que a
  // política de Storage usa para autorizar. Ver 0009_storage.sql.
  storagePath: '$household/$receiptId.jpg',
  ocrStatus: const Value('done'),
  ocrText: Value(rawText),
  ocrParsed: Value(jsonEncode(parsed.toJson())),
  ocrConfidence: Value(parsed.confidence),
));

// 2. Enfileira o upload (fila separada da outbox — binário tem
//    política de retry própria)
await uploadQueueDao.enqueue(receiptId, localPath, storagePath);

// 3. Abre a entrada rápida já preenchida
context.push('/quick-add', extra: QuickAddPreset.fromReceipt(parsed, receiptId));
```

A imagem local fica em `getApplicationDocumentsDirectory()`, **não** em cache: o sistema apaga cache sem avisar, e um recibo que sumiu antes de subir é dado perdido. Depois do upload confirmado, o arquivo local pode virar só a miniatura.

## Visualização

Miniatura de 200px no detalhe do lançamento; toque abre em tela cheia com zoom. A imagem cheia vem do Storage por URL assinada, com validade de 1 hora:

```dart
final url = await supabase.storage.from('receipts')
    .createSignedUrl(path, 3600);
```

URL assinada e não pública porque o bucket é privado — é comprovante com CPF e endereço impressos. `cached_network_image` guarda em cache local para não rebaixar a mesma foto toda vez.

## Custo de armazenamento

| Item | Valor |
|---|---|
| Foto comprimida | ~200 KB |
| Miniatura | ~15 KB |
| Cota gratuita | 1 GB |
| **Capacidade** | **~4.600 recibos** |

Se um dia apertar: manter a foto cheia por 12 meses e depois deixar só a miniatura mais o texto do OCR. O texto é o que tem valor de consulta a longo prazo; a foto importa para garantia e devolução, que têm prazo curto. Não implementar agora — só deixar claro que a saída existe.

## Critérios de aceite

- [ ] Cupom de mercado legível: valor e data corretos em 80% dos casos
- [ ] Comprovante de Pix (print de tela): valor correto em 90%
- [ ] Nunca salva sem confirmação do usuário
- [ ] Funciona offline por completo, do OCR ao salvar
- [ ] Upload retoma sozinho quando a rede volta
- [ ] Recognizer sempre fechado — 20 capturas seguidas sem crescimento de memória
- [ ] Foto local sobrevive à limpeza de cache do sistema
