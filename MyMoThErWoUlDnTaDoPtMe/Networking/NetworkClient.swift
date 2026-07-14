import Foundation

actor NetworkClient {
    static let shared: NetworkClient = {
        return NetworkClient()
    }()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    init(session: URLSession) {
        self.session = session
    }

    func fetch(url: URL) async throws -> Data {
        let request = URLRequest(url: url)
        return try await perform(request)
    }

    func fetch(request: URLRequest) async throws -> Data {
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.network(URLError(.badServerResponse))
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 429 {
                    throw AppError.rateLimitExceeded
                }
                throw AppError.network(URLError(.badServerResponse))
            }
            return data
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            throw AppError.network(error)
        } catch {
            throw AppError.unknown(error)
        }
    }
}
