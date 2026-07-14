import Foundation

enum PlayerState: Equatable {
    case stopped
    case playing
    case paused
    case loading
    case error(String)
}
