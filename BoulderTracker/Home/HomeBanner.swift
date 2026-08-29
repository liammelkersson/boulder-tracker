import SwiftUI

struct HomeBanner: View {
    @AppStorage(AppPreferences.profileNameKey)
    private var profileName = AppPreferences.defaultProfileName
    let sessions: [Session]

    static let height: CGFloat = 260

    private static let bannerHeight = height

    private var climbingDays: Int {
        StatsAggregator.climbingDayCount(of: sessions, calendar: .current)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            bannerImage
            bannerScrim
            greetingText
        }
        .frame(height: Self.bannerHeight)
        .clipped()
    }

    private var bannerImage: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: Self.bannerHeight)
            .frame(maxWidth: .infinity)
            .overlay {
                Image("GymBanner")
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }

    private var bannerScrim: some View {
        LinearGradient(
            colors: [
                Color(hex: 0x060708).opacity(0.1),
                Color(hex: 0x060708).opacity(0.5),
                Color(hex: 0x060708).opacity(0.85),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var greetingText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(TimeOfDayGreeting.current())
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            Text(profileName)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            Text("\(climbingDays) climbing \(climbingDays == 1 ? "day" : "days") in the last 3 months")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 38)
    }
}

enum TimeOfDayGreeting {
    private static let morningEndHour = 12
    private static let afternoonEndHour = 18

    static func current(date: Date = .now, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        if hour < morningEndHour { return "Good morning" }
        if hour < afternoonEndHour { return "Good afternoon" }
        return "Good evening"
    }
}
