import Foundation

protocol AudioPlayerProtocol: AnyObject {
    var state: PlayerState { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var currentTrack: SearchResult? { get }
    func play(url: URL, track: SearchResult?)
    func toggle()
    func stop()
    func seek(to time: TimeInterval)
    func setVolume(_ volume: Float)
}
