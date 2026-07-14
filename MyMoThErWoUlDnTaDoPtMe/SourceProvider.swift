import Foundation

protocol SourceProvider {
    func search(query: String) async throws -> [SearchResult]
    func streamURL(for result: SearchResult) async throws -> URL
}
