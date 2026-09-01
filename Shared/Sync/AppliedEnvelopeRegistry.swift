import Foundation
import OSLog

/// Remembers recently applied envelope ids so the dual-channel transport's
/// duplicate deliveries become no-ops. Bounded FIFO, persisted so a duplicate
/// arriving after a relaunch is still recognised.
@MainActor
final class AppliedEnvelopeRegistry {
    static let capacity = 512

    private let fileURL: URL
    private var orderedIDs: [UUID]
    private var idSet: Set<UUID>

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.orderedIDs = Self.storedIDs(at: fileURL)
        self.idSet = Set(orderedIDs)
    }

    func contains(_ id: UUID) -> Bool {
        idSet.contains(id)
    }

    func record(_ id: UUID) {
        guard idSet.insert(id).inserted else { return }
        orderedIDs.append(id)
        if orderedIDs.count > Self.capacity {
            idSet.remove(orderedIDs.removeFirst())
        }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(orderedIDs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Logger.sync.error("Applied-envelope registry write failed: \(error)")
        }
    }

    private static func storedIDs(at fileURL: URL) -> [UUID] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            return try JSONDecoder().decode([UUID].self, from: data)
        } catch {
            Logger.sync.error("Applied-envelope registry unreadable, starting empty: \(error)")
            return []
        }
    }
}
