import Foundation

@MainActor
class SleepTimerManager: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var remainingSeconds: TimeInterval = 0

    private var timer: Timer?
    private var onExpire: (() -> Void)?

    var formattedRemaining: String {
        guard isActive else { return "" }
        let m = Int(remainingSeconds) / 60
        let s = Int(remainingSeconds) % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    func start(minutes: Int, onExpire: @escaping () -> Void) {
        stop()
        self.onExpire = onExpire
        remainingSeconds = TimeInterval(minutes * 60)
        isActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.remainingSeconds -= 1
                if self.remainingSeconds <= 0 {
                    self.stop()
                    self.onExpire?()
                }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        remainingSeconds = 0
        onExpire = nil
    }

    func addMinutes(_ minutes: Int) {
        guard isActive else { return }
        remainingSeconds += TimeInterval(minutes * 60)
    }
}
