import SwiftUI

@main
struct BitcoinTickerApp: App {

    // @StateObject instead of @State + @Observable (macOS 14+).
    // The service starts polling as soon as it is created.
    @StateObject private var priceService = BitcoinPriceService()

    var body: some Scene {
        MenuBarExtra {
            BitcoinMenuView(priceService: priceService)
        } label: {
            TickerLabel(priceService: priceService)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The text shown in the menu bar.
///
/// On macOS 13 a MenuBarExtra label reliably renders a single `Text`, so the
/// price and change are built as one concatenated `Text` rather than an HStack.
private struct TickerLabel: View {

    @ObservedObject var priceService: BitcoinPriceService

    var body: some View {
        if let price = priceService.price,
           let change = priceService.change24h {

            let arrow = change >= 0 ? "▲" : "▼"

            let priceText = price.formatted(
                .currency(code: "USD").precision(.fractionLength(0))
            )

            let changeText = String(format: "%.1f%%", abs(change))

            Text(priceText)
                + Text(" \(arrow)\(changeText)")
                    .foregroundColor(change >= 0 ? .green : .red)

        } else {
            Text("BTC …")
        }
    }
}
