import SwiftUI

struct BitcoinMenuView: View {

    @ObservedObject var priceService: BitcoinPriceService

    @StateObject private var launchAtLogin = LaunchAtLoginManager()

    var body: some View {

        VStack(alignment: .leading, spacing: 16) {

            // Header
            HStack {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.title)

                Text("Bitcoin")
                    .font(.headline)

                Spacer()

                Button {
                    Task {
                        await priceService.fetchPrice()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }

            Divider()

            // Price
            if let price = priceService.price {

                Text(price, format: .currency(code: "USD"))
                    .font(.system(size: 30, weight: .semibold))
                    .monospacedDigit()

            } else {
                Text("Loading…")
                    .font(.title)
            }

            // 24-hour change
            if let change = priceService.change24h {

                HStack(spacing: 5) {

                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")

                    Text(String(format: "%.2f%%", abs(change)))

                    Text("24h")
                        .foregroundColor(.secondary)
                }
                .foregroundColor(change >= 0 ? .green : .red)
            }

            Divider()

            // Status
            if let lastUpdated = priceService.lastUpdated {

                HStack {
                    Text("Last updated")

                    Spacer()

                    Text(lastUpdated, format: .dateTime.hour().minute().second())
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }

            if let error = priceService.errorMessage {

                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            )

            Divider()

            HStack {

                Text(priceService.source)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            launchAtLogin.refresh()
        }
    }
}
