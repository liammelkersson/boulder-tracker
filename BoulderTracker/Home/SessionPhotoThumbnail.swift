import SwiftUI

struct SessionPhotoThumbnail: View {
    @Environment(\.palette) private var palette
    let session: Session
    var size: CGFloat = 40

    private static let photoStore = PhotoStore.makeDefault()

    var body: some View {
        Group {
            if let image = sessionPhoto() ?? firstProblemPhoto() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 10))
    }

    private var placeholder: some View {
        ZStack {
            palette.pill
            Image(systemName: "figure.climbing")
                .font(.system(size: size * 0.4))
                .foregroundStyle(palette.textFaint)
        }
    }

    private func sessionPhoto() -> UIImage? {
        guard let filename = session.photoFilename,
              let data = Self.photoStore.loadPhoto(named: filename) else { return nil }
        return UIImage(data: data)
    }

    private func firstProblemPhoto() -> UIImage? {
        for problem in session.problems {
            if let filename = problem.photoFilename,
               let data = Self.photoStore.loadPhoto(named: filename),
               let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }
}
