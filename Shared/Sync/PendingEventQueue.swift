import Foundation
import OSLog

/// Outbound envelopes held on disk until the peer confirms delivery, so a session
/// logged with the phone out of range survives the app being terminated.
final class PendingEventQueue {
    private let fileURL: URL
    private var envelopes: [SyncEnvelope]

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.envelopes = Self.storedEnvelopes(at: fileURL)
    }

    var pending: [SyncEnvelope] { envelopes }

    func append(_ envelope: SyncEnvelope) {
        envelopes.append(envelope)
        persist()
    }

    func remove(deliveredID: UUID) {
        envelopes.removeAll { $0.id == deliveredID }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(envelopes)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Logger.sync.error("Pending event queue write failed: \(error)")
        }
    }

    private static func storedEnvelopes(at fileURL: URL) -> [SyncEnvelope] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            return try JSONDecoder().decode([SyncEnvelope].self, from: data)
        } catch {
            Logger.sync.error("Pending event queue unreadable, starting empty: \(error)")
            return []
        }
    }
}

extension PendingEventQueue {
    static func inApplicationSupport(named filename: String) -> PendingEventQueue {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        return PendingEventQueue(fileURL: directory.appendingPathComponent(filename))
    }
}
