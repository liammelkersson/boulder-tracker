import SwiftUI

struct HighlightCard: View {
    let sessions: [Session]
    private let photoStore = PhotoStore.makeDefault()

    private var proudest: ProblemAttempt? { StatsAggregator.proudestSend(of: sessions) }

    var body: some View {
        if let attempt = proudest {
            VStack(alignment: .leading, spacing: 8) {
                Text("Proudest send")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                proudestDescription(for: attempt)
                photoThumbnail(for: attempt)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassEffect(in: .rect(cornerRadius: 20))
        }
    }

    private func proudestDescription(for attempt: ProblemAttempt) -> some View {
        let gymName = attempt.session?.gym?.name ?? "your gym"
        return (
            Text("At \(gymName) you sent a ")
            + Text(attempt.colorGrade.displayName)
                .foregroundStyle(attempt.colorGrade.displayColor)
                .bold()
            + Text(" problem after \(attempt.attemptCount) attempts!")
        )
        .font(.headline)
    }

    @ViewBuilder
    private func photoThumbnail(for attempt: ProblemAttempt) -> some View {
        if let filename = attempt.photoFilename,
           let imageData = photoStore.loadPhoto(named: filename),
           let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 140)
                .clipShape(.rect(cornerRadius: 12))
        }
    }
}
