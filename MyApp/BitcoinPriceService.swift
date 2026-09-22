import Foundation

@MainActor
@Observable
final class BitcoinPriceService {

    var price: Double?
    var change24h: Double?
    var errorMessage: String?

    func fetchPrice() async {
        guard let url = URL(
            string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true"
        ) else {
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let result = try JSONDecoder().decode(
                BitcoinPriceResponse.self,
                from: data
            )

            price = result.bitcoin.usd
            change24h = result.bitcoin.usd24hChange
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
