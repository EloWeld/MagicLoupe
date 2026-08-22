import Foundation

@MainActor
final class Debouncer {
    private var task: Task<Void, Never>?

    func schedule(milliseconds: UInt64 = 450, _ work: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(milliseconds))
            guard !Task.isCancelled else { return }
            work()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
