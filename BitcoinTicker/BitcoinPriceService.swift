import Foundation
import Combine

/// Fetches the Bitcoin price every 60 seconds.
///
/// Tries CoinGecko first. CoinGecko's keyless API is rate-limited per public IP
/// (~10–30 calls/min shared by everyone behind that IP), so on corporate
/// networks or VPNs it often answers 429. When that happens we fall back to
/// Coinbase Exchange's public stats endpoint, which has much higher limits.
///
/// Uses `ObservableObject` + `@Published` (macOS 10.15+) instead of the
/// `@Observable` macro, which requires macOS 14 Sonoma.
@MainActor
final class BitcoinPriceService: ObservableObject {

    @Published private(set) var price: Double?
    @Published private(set) var change24h: Double?
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var source: String = "CoinGecko"

    private var refreshTask: Task<Void, Never>?

    private static let coinGeckoURL = URL(
        string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true"
    )!

    private static let coinbaseURL = URL(
        string: "https://api.exchange.coinbase.com/products/BTC-USD/stats"
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
        var failures: [String] = []

        do {
            let quote = try await fetchCoinGecko()
            apply(quote, source: "CoinGecko")
            return
        } catch {
            failures.append("CoinGecko: \(Self.describe(error))")
            print("CoinGecko fetch failed:", error)
        }

        do {
            let quote = try await fetchCoinbase()
            apply(quote, source: "Coinbase")
            return
        } catch {
            failures.append("Coinbase: \(Self.describe(error))")
            print("Coinbase fetch failed:", error)
        }

        // Keep showing the last good price; just report why it's stale.
        errorMessage = failures.joined(separator: "\n")
    }

    // MARK: - Sources

    private struct Quote {
        let price: Double
        let change24h: Double
    }

    private func apply(_ quote: Quote, source: String) {
        price = quote.price
        change24h = quote.change24h
        self.source = source
        lastUpdated = Date()
        errorMessage = nil
    }

    private func fetchCoinGecko() async throws -> Quote {
        let data = try await get(Self.coinGeckoURL)
        let result = try JSONDecoder().decode(CoinGeckoResponse.self, from: data)
        return Quote(price: result.bitcoin.usd, change24h: result.bitcoin.usd24hChange)
    }

    private func fetchCoinbase() async throws -> Quote {
        let data = try await get(Self.coinbaseURL)
        let stats = try JSONDecoder().decode(CoinbaseStats.self, from: data)

        guard let last = Double(stats.last),
              let open = Double(stats.open),
              open > 0 else {
            throw URLError(.cannotParseResponse)
        }

        // Coinbase's "open" is the price 24 hours ago, so this is a rolling 24h change.
        return Quote(price: last, change24h: (last - open) / open * 100)
    }

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("BitcoinTicker/1.2 (macOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard http.statusCode == 200 else {
            throw HTTPStatusError(statusCode: http.statusCode)
        }
        return data
    }

    private static func describe(_ error: Error) -> String {
        if let status = error as? HTTPStatusError {
            return status.message
        }
        if error is DecodingError {
            return "unexpected response format"
        }
        return error.localizedDescription
    }
}

private struct HTTPStatusError: Error {
    let statusCode: Int

    var message: String {
        switch statusCode {
        case 429: return "rate limited (HTTP 429), will retry"
        case 403: return "access blocked (HTTP 403), possibly by your network"
        case 500...599: return "server error (HTTP \(statusCode))"
        default: return "HTTP \(statusCode)"
        }
    }
}

private struct CoinGeckoResponse: Decodable {
    let bitcoin: Price

    struct Price: Decodable {
        let usd: Double
        let usd24hChange: Double

        enum CodingKeys: String, CodingKey {
            case usd
            case usd24hChange = "usd_24h_change"
        }
    }
}

private struct CoinbaseStats: Decodable {
    let open: String
    let last: String
}
