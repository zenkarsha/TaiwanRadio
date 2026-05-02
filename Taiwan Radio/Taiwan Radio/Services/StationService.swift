import Foundation

struct StationService {
    private static let urls: [URL] = [
        "https://all.api.radio-browser.info/json/stations/bycountrycodeexact/TW",
        "https://at1.api.radio-browser.info/json/stations/bycountrycodeexact/TW",
        "https://nl1.api.radio-browser.info/json/stations/bycountrycodeexact/TW",
        "https://de1.api.radio-browser.info/json/stations/bycountrycodeexact/TW"
    ].compactMap(URL.init(string:))

    private let decoder = JSONDecoder()

    func fetchStations() async throws -> [RadioStation] {
        var lastError: Error?

        for endpoint in Self.urls {
            do {
                var request = URLRequest(url: endpoint)
                request.timeoutInterval = 15
                request.cachePolicy = .reloadIgnoringLocalCacheData

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, 200 ..< 300 ~= httpResponse.statusCode else {
                    throw URLError(.badServerResponse)
                }

                let decoded = try decoder.decode([RadioStation].self, from: data)
                return sortedStations(decoded.filter { !$0.streamURLs.isEmpty })
            } catch {
                lastError = error
            }
        }

        throw lastError ?? URLError(.badServerResponse)
    }

    func errorMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return "目前無法連上 Radio Browser 節點，已嘗試多個伺服器。"
            default:
                return urlError.localizedDescription
            }
        }

        return error.localizedDescription
    }

    func sortedStations(_ stations: [RadioStation]) -> [RadioStation] {
        stations.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedDescending
        }
    }

    func hotStations(from stations: [RadioStation], limit: Int = 30) -> [RadioStation] {
        Array(stations.sorted { lhs, rhs in
            if lhs.votes != rhs.votes {
                return (lhs.votes ?? 0) > (rhs.votes ?? 0)
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }.prefix(limit))
    }
}
