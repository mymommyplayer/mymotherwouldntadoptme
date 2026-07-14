import Foundation

protocol QueueManagerProtocol: AnyObject {
    var items: [QueueItem] { get }
    var currentIndex: Int? { get }
    var currentItem: QueueItem? { get }
    func next()
    func previous()
    func add(_ item: QueueItem)
    func remove(at index: Int)
    func setCurrent(index: Int)
    func clear()
}
