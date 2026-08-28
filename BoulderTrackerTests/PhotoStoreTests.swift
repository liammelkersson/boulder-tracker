import Testing
import Foundation
@testable import BoulderTracker

struct PhotoStoreTests {
    private func makeTemporaryStore() -> PhotoStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return PhotoStore(directory: dir)
    }

    @Test func savedPhotoRoundTrips() throws {
        let store = makeTemporaryStore()
        let original = Data([0xFF, 0xD8, 0xFF, 0xE0])

        let filename = try store.savePhoto(original)
        let loaded = store.loadPhoto(named: filename)

        #expect(loaded == original)
    }

    @Test func deletedPhotoIsGone() throws {
        let store = makeTemporaryStore()
        let filename = try store.savePhoto(Data([0x01]))

        try store.deletePhoto(named: filename)

        #expect(store.loadPhoto(named: filename) == nil)
    }

    @Test func savedFilenamesAreUnique() throws {
        let store = makeTemporaryStore()
        let first = try store.savePhoto(Data([0x01]))
        let second = try store.savePhoto(Data([0x01]))
        #expect(first != second)
    }
}
