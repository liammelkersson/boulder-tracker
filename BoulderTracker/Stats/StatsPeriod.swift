import Foundation

enum StatsPeriod: String, CaseIterable, Identifiable {
    case month, threeMonths, year, all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .month: "Month"
        case .threeMonths: "3 Months"
        case .year: "Year"
        case .all: "All"
        }
    }

    func interval(endingAt referenceDate: Date, calendar: Calendar) -> DateInterval? {
        let monthsBack: Int
        switch self {
        case .month: monthsBack = 1
        case .threeMonths: monthsBack = 3
        case .year: monthsBack = 12
        case .all: return nil
        }
        guard let start = calendar.date(byAdding: .month, value: -monthsBack, to: referenceDate) else {
            return nil
        }
        return DateInterval(start: start, end: referenceDate)
    }
}
