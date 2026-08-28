import Foundation

struct PhotoStore {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    static func makeDefault() -> PhotoStore {
        let documents = URL.documentsDirectory
        return PhotoStore(directory: documents.appendingPathComponent("RoutePhotos", isDirectory: true))
    }

    func savePhoto(_ jpegData: Data) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).jpg"
        try jpegData.write(to: photoURL(for: filename), options: .atomic)
        return filename
    }

    func photoURL(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    func loadPhoto(named filename: String) -> Data? {
        try? Data(contentsOf: photoURL(for: filename))
    }

    func deletePhoto(named filename: String) throws {
        try FileManager.default.removeItem(at: photoURL(for: filename))
    }
}
