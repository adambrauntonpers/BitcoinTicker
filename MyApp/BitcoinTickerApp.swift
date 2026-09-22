import SwiftUI

@main
struct BitcoinTickerApp: App {

    @State private var priceService = BitcoinPriceService()

    var body: some Scene {

        MenuBarExtra {
            VStack(alignment: .leading, spacing: 8) {

                Text("Bitcoin")
                    .font(.headline)

                if let price = priceService.price {
                    Text(price, format: .currency(code: "USD"))
                        .font(.title2)
                } else {
                    Text("Loading...")
                }

                if let change = priceService.change24h {
                    Text("\(change >= 0 ? "▲" : "▼") \(abs(change), specifier: "%.2f")% today")
                }

                Divider()

                Button("Refresh") {
                    Task {
                        await priceService.fetchPrice()
                    }
                }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
            .task {
                await priceService.fetchPrice()
            }

        } label: {
            if let price = priceService.price,
               let change = priceService.change24h {

                let arrow = change >= 0 ? "▲" : "▼"
                let priceText = price.formatted(
                    .currency(code: "USD")
                    .precision(.fractionLength(0))
                )
                let changeText = String(format: "%.1f%%", abs(change))

                Text("\(priceText) \(arrow)\(changeText)")

            } else {
                Text("BTC …")
            }
        }
    }
}
