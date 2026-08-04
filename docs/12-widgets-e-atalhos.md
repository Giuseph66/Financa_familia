# 12 — Widgets e Atalhos de Sistema

O pedido original: **atalhos na tela inicial e na tela de bloqueio**. Este documento diz exatamente o que é possível em cada plataforma, o que não é, e como implementar.

## O que Flutter não faz

Precisa estar claro antes de começar: **Flutter não renderiza widget de tela inicial.** O sistema operacional desenha esses widgets fora do processo do app, num ambiente restrito onde o motor do Flutter não roda.

Então, obrigatoriamente:

- **Android** — Kotlin com Jetpack Glance (ou `RemoteViews`, mais antigo e mais verboso)
- **iOS** — Swift com SwiftUI e WidgetKit

O pacote `home_widget` **não** desenha nada. Ele faz a ponte de dados: o app Flutter escreve valores num armazenamento compartilhado, o widget nativo lê e desenha. Essa é toda a função dele, e é suficiente.

O caminho é: o app, depois de cada sync, calcula os números e escreve; o widget nativo lê e renderiza; tocar no widget dispara um deep link que o Flutter trata.

## Matriz de possibilidades

| Recurso | Android | iOS |
|---|---|---|
| Widget de tela inicial | Sim — Glance, API 23+ | Sim — WidgetKit, iOS 14+ |
| Widget de tela de bloqueio | **Não para celular.** Só tablet, Android 15+ | **Sim** — WidgetKit accessory, iOS 16+ |
| Atalho no ícone (toque longo) | Sim — App Shortcuts | Sim — Quick Actions |
| Painel de acesso rápido | Sim — Quick Settings Tile | Control Center, iOS 18+ |
| Assistente de voz | Google Assistant (limitado) | Siri via AppIntents |
| Alvo de compartilhamento | Sim — intent-filter | Sim — Share Extension |
| Notificação persistente com ação | Sim | Não (iOS não tem) |

**A resposta honesta sobre tela de bloqueio:** no iOS funciona bem, é um recurso de primeira classe. No **Android celular, não existe** — o Google removeu widgets de tela de bloqueio no Android 5 e só devolveu no Android 15 para tablets. A alternativa real no Android é a combinação de **Quick Settings Tile** (acessível puxando a barra de status, o que funciona por cima da tela de bloqueio) com uma **notificação persistente opcional** que traz botões de ação. Não é a mesma coisa, mas resolve o mesmo problema: registrar sem destravar e procurar o app.

## Ponte de dados

```dart
// lib/features/shortcuts/home_widget_service.dart
class HomeWidgetService {
  static const _androidWidget = 'FinancaWidgetProvider';
  static const _iosWidget = 'FinancaWidget';

  Future<void> refresh() async {
    final s = await _repo.currentMonthSummary();

    // Valores JÁ FORMATADOS. O widget nativo não formata moeda nem
    // sabe locale: replicar a formatação em Kotlin e em Swift daria
    // três implementações divergindo. O Dart formata, o nativo exibe.
    await HomeWidget.saveWidgetData('balance',  s.balance.formatted);
    await HomeWidget.saveWidgetData('income',   s.income.formatted);
    await HomeWidget.saveWidgetData('expense',  s.expense.formatted);
    await HomeWidget.saveWidgetData('month',    s.monthLabel);
    await HomeWidget.saveWidgetData('is_negative', s.balance.cents < 0);

    // Categorias favoritas para os botões de registro em um toque.
    final favs = await _repo.favoriteCategories(limit: 4);
    for (var i = 0; i < 4; i++) {
      await HomeWidget.saveWidgetData('cat_${i}_id',    favs[i].id);
      await HomeWidget.saveWidgetData('cat_${i}_icon',  favs[i].iconName);
      await HomeWidget.saveWidgetData('cat_${i}_label', favs[i].name);
      await HomeWidget.saveWidgetData('cat_${i}_color', favs[i].colorHex);
    }

    await HomeWidget.updateWidget(
      androidName: _androidWidget, iosName: _iosWidget);
  }
}
```

Chamar `refresh()` depois de: cada gravação, cada sync bem-sucedido, e na virada do mês. Widget desatualizado mostrando saldo do mês passado destrói a confiança no app inteiro.

No iOS, `home_widget` precisa de **App Group** configurado nos dois alvos (app e extensão), em Signing & Capabilities. Sem isso os dados não atravessam e o widget aparece vazio — sem erro nenhum, o que torna a depuração desagradável.

## Android

### Widget de tela inicial (Glance)

Três tamanhos:

```
2×1  ┌──────────────┐   4×1  ┌────────────────────────────┐
     │ Agosto       │        │  🛒    🍔    ⛽    ➕      │
     │ R$ 1.240,50  │        │  Mercado Lanche Posto Outro│
     └──────────────┘        └────────────────────────────┘

4×2  ┌────────────────────────────┐
     │ Agosto            ↻        │
     │ R$ 1.240,50                │
     │ ↓ 4.200,00   ↑ 2.959,50    │
     │ ─────────────────────────  │
     │  🛒    🍔    ⛽    📷      │
     └────────────────────────────┘
```

```kotlin
// android/app/src/main/kotlin/br/com/neurelix/financa/widget/BalanceWidget.kt
class BalanceWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        // home_widget grava em SharedPreferences com este nome fixo.
        val prefs = context.getSharedPreferences(
            "HomeWidgetPreferences", Context.MODE_PRIVATE)

        provideContent {
            GlanceTheme {
                Column(GlanceModifier.fillMaxSize().padding(12.dp)
                    .background(GlanceTheme.colors.widgetBackground)
                    // O corpo do widget abre o app; os botões têm ação
                    // própria e o toque não vaza para o container.
                    .clickable(actionStartActivity(
                        deepLink("financa://")))) {

                    Text(prefs.getString("month", "") ?: "",
                         style = TextStyle(fontSize = 12.sp))

                    Text(prefs.getString("balance", "R$ 0,00") ?: "",
                         style = TextStyle(
                             fontSize = 24.sp,
                             fontWeight = FontWeight.Bold,
                             color = if (prefs.getBoolean("is_negative", false))
                                     ColorProvider(Color(0xFFB3261E))
                                     else GlanceTheme.colors.onSurface))

                    Spacer(GlanceModifier.height(8.dp))

                    Row(GlanceModifier.fillMaxWidth()) {
                        for (i in 0..3) {
                            CategoryButton(prefs, i, GlanceModifier.defaultWeight())
                        }
                    }
                }
            }
        }
    }

    // Cada botão abre a entrada rápida COM a categoria já escolhida.
    // Do bloqueio ao lançamento salvo: dois toques.
    private fun deepLink(uri: String) = Intent(Intent.ACTION_VIEW, Uri.parse(uri))
        .setPackage("br.com.neurelix.financa")
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
}

class BalanceWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget = BalanceWidget()
}
```

`GlanceTheme` segue automaticamente o Material You do aparelho, então o widget combina com o papel de parede do usuário sem código extra.

Registro em `AndroidManifest.xml`:

```xml
<receiver android:name=".widget.BalanceWidgetReceiver"
          android:exported="true">
  <intent-filter>
    <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
  </intent-filter>
  <meta-data android:name="android.appwidget.provider"
             android:resource="@xml/balance_widget_info" />
</receiver>
```

`res/xml/balance_widget_info.xml` com `minWidth`, `minHeight`, `resizeMode="horizontal|vertical"`, `targetCellWidth`/`targetCellHeight` (Android 12+) e `previewLayout`. Preview importa: sem ela, o widget aparece como um retângulo cinza no seletor e ninguém o adiciona.

### Quick Settings Tile

O caminho mais rápido do Android, e a resposta prática ao pedido de tela de bloqueio: a barra de status desce por cima do bloqueio.

```kotlin
// QuickAddTileService.kt
class QuickAddTileService : TileService() {
    override fun onClick() {
        super.onClick()
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("financa://quick-add"))
            .setPackage(packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        // Em Android 14+ startActivityAndCollapse exige PendingIntent;
        // a sobrecarga com Intent lança IllegalArgumentException.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                PendingIntent.getActivity(this, 0, intent,
                    PendingIntent.FLAG_IMMUTABLE))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    override fun onStartListening() {
        // Mostra o saldo no rótulo do tile — informação de graça, sem
        // abrir nada.
        val prefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
        qsTile.label = "Registrar gasto"
        qsTile.subtitle = prefs.getString("balance", "")
        qsTile.state = Tile.STATE_ACTIVE
        qsTile.updateTile()
    }
}
```

O sistema pede autorização do usuário para desbloquear o app a partir do tile, o que é o comportamento correto — o app tem dado financeiro.

### App Shortcuts

Toque longo no ícone. Estáticos, definidos em `res/xml/shortcuts.xml`:

```xml
<shortcuts xmlns:android="http://schemas.android.com/apk/res/android">
  <shortcut android:shortcutId="expense"
            android:icon="@drawable/ic_expense"
            android:shortcutShortLabel="@string/shortcut_expense">
    <intent android:action="android.intent.action.VIEW"
            android:data="financa://quick-add?kind=expense"
            android:targetPackage="br.com.neurelix.financa"
            android:targetClass="br.com.neurelix.financa.MainActivity" />
  </shortcut>
  <!-- receita, foto do recibo -->
</shortcuts>
```

Dinâmicos (as categorias mais usadas) via `quick_actions` no Dart, atualizados junto com o widget.

### Notificação persistente (opcional)

Ligada em Ajustes › Atalhos, desligada por padrão. Notificação de baixa prioridade, silenciosa, permanente, com botões "Gasto", "Receita" e "Foto". Aparece na tela de bloqueio e é o mais perto que Android celular chega de um widget de bloqueio.

Desligada por padrão porque notificação permanente incomoda parte dos usuários, e o app não deve presumir. Quem quer o atalho máximo liga.

### Alvo de compartilhamento

```xml
<intent-filter>
  <action android:name="android.intent.action.SEND" />
  <category android:name="android.intent.category.DEFAULT" />
  <data android:mimeType="image/*" />
  <data android:mimeType="application/pdf" />
</intent-filter>
```

Com `receive_sharing_intent` no Dart. Recebeu o comprovante do Pix no WhatsApp? Compartilha para o Finança, que abre a entrada rápida com a imagem anexada e o OCR já rodando.

## iOS

### Widget de tela inicial e de bloqueio

Um alvo Widget Extension em Xcode, chamado `FinancaWidget`. Mesmo código serve para tela inicial e bloqueio; muda a família:

```swift
// ios/FinancaWidget/FinancaWidget.swift
struct FinancaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FinancaWidget", provider: Provider()) { entry in
            FinancaWidgetView(entry: entry)
        }
        .configurationDisplayName("Finança")
        .description("Saldo do mês e registro rápido")
        .supportedFamilies([
            .systemSmall, .systemMedium,        // tela inicial
            .accessoryCircular,                 // bloqueio: só o saldo
            .accessoryRectangular,              // bloqueio: saldo + entradas/saídas
            .accessoryInline                    // bloqueio: uma linha junto ao relógio
        ])
    }
}

struct FinancaWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: Entry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("R$ \(entry.balance)")
        case .accessoryCircular:
            Gauge(value: entry.budgetUsed) { Text("R$") }
                .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text(entry.month).font(.caption2)
                Text(entry.balance).font(.headline)
                Text("↓\(entry.income)  ↑\(entry.expense)").font(.caption2)
            }
        default:
            HomeScreenView(entry: entry)
                .widgetURL(URL(string: "financa://quick-add"))
        }
    }
}
```

Os widgets de acessório (bloqueio) são **monocromáticos** — o sistema aplica um filtro de vibrância e cor nenhuma sobrevive. Projete pensando em forma e contraste, não em cor. Testar só na tela inicial e assumir que o bloqueio fica igual é o erro clássico aqui.

Ler os dados do App Group:

```swift
let defaults = UserDefaults(suiteName: "group.br.com.neurelix.financa")
let balance = defaults?.string(forKey: "balance") ?? "R$ 0,00"
```

### Control Center (iOS 18+)

```swift
@available(iOS 18.0, *)
struct QuickAddControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "QuickAddControl") {
            ControlWidgetButton(action: OpenQuickAddIntent()) {
                Label("Registrar gasto", systemImage: "plus.circle.fill")
            }
        }
    }
}
```

Isso deixa o usuário colocar um botão do app no Control Center e — no iPhone com iOS 18 — **substituir a lanterna ou a câmera no botão da tela de bloqueio**. É o equivalente iOS mais próximo do que o Quick Settings Tile faz no Android.

### Siri e Quick Actions

```swift
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar gasto"
    static var openAppWhenRun = true

    @Parameter(title: "Valor") var amount: Double?

    func perform() async throws -> some IntentResult {
        // Não grava nada aqui: abre o app com o valor preenchido.
        // Ver a regra de segurança em 09-navegacao-e-telas.md — nenhum
        // ponto de entrada externo grava sem o usuário confirmar.
        UserDefaults(suiteName: "group.br.com.neurelix.financa")?
            .set(amount, forKey: "pending_amount")
        return .result()
    }
}
```

"Ei Siri, registrar gasto no Finança" abre a entrada rápida.

Quick Actions (toque longo no ícone) via `UIApplicationShortcutItems` no `Info.plist` ou pelo pacote `quick_actions`.

## Como as duas plataformas se encontram

Deep link é o contrato comum. Todo ponto de entrada — widget Android, widget iOS, tile, Siri, atalho de ícone, notificação — dispara uma URI `financa://`, e o `go_router` trata. O código Flutter não sabe nem precisa saber de onde veio.

Exceto por um detalhe que vale registrar: o lançamento criado por widget grava `source = 'widget'`. Depois de um mês, dá para olhar a distribuição e saber se o investimento nos widgets valeu.

## Critérios de aceite

- [ ] Widget Android nos três tamanhos, atualizando em até 30s após um lançamento
- [ ] Toque em categoria do widget abre a entrada rápida já com ela selecionada
- [ ] Quick Settings Tile funciona a partir da tela bloqueada
- [ ] Toque longo no ícone mostra 3 atalhos, Android e iOS
- [ ] Widget iOS de tela inicial nos dois tamanhos
- [ ] Widget iOS de bloqueio nas três famílias de acessório, legível em monocromático
- [ ] Control Center funcional em iOS 18
- [ ] Compartilhar imagem de outro app abre a captura de recibo
- [ ] Widget mostra dado correto imediatamente após a virada do mês
- [ ] Nenhum ponto de entrada externo grava dado sem confirmação na tela
