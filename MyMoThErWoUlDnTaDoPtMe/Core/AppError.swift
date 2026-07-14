import Foundation

enum AppError: LocalizedError {
    case network(URLError)
    case parsing(DecodingError)
    case streamExpired
    case sourceUnavailable(String)
    case notFound(String)
    case rateLimitExceeded
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsing(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .streamExpired:
            return "Stream URL expired, refresh needed"
        case .sourceUnavailable(let reason):
            return "Source unavailable: \(reason)"
        case .notFound(let query):
            return "No results for: \(query)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .unknown(let error):
            return "Unexpected error: \(error.localizedDescription)"
        }
    }
}
