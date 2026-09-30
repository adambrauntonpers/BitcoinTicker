import Foundation
import Combine

/// Fetches the Bitcoin price from CoinGecko every 60 seconds.
///
/// Uses `ObservableObject` + `@Published` (available on macOS 10.15+) instead of
/// the `@Observable` macro, which requires macOS 14 Sonoma.
@MainActor
final class BitcoinPriceService: ObservableObject {

    @Published private(set) var price: Double?
    @Published private(set) var change24h: Double?
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private var refreshTask: Task<Void, Never>?

    private static let endpoint = URL(
        string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true"
    )!

    // `nonisolated` so it can be created from `@StateObject`'s initializer on
    // every Xcode/SDK version that runs on Ventura; polling hops to the main actor.
    nonisolated init() {
        Task { @MainActor [weak self] in
            self?.start()
        }
    }

    func start() {
        guard refreshTask == nil else { return }

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.fetchPrice()
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            }
        }
    }

    func fetchPrice() async {
        var request = URLRequest(url: Self.endpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let result = try JSONDecoder().decode(BitcoinPriceResponse.self, from: data)

            price = result.bitcoin.usd
            change24h = result.bitcoin.usd24hChange
            lastUpdated = Date()
            errorMessage = nil

        } catch {
            errorMessage = error.localizedDescription
            print("Price fetch failed:", error)
        }
    }
}

private struct BitcoinPriceResponse: Decodable {
    let bitcoin: BitcoinPrice
}

private struct BitcoinPrice: Decodable {
    let usd: Double
    let usd24hChange: Double

    enum CodingKeys: String, CodingKey {
        case usd
        case usd24hChange = "usd_24h_change"
    }
}
