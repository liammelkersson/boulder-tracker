import SwiftUI

struct MonthCalendarGrid: View {
    @Environment(\.palette) private var palette
    let month: Date
    let sessions: [Session]
    @Binding var selectedDay: Date?

    private let calendar = Calendar.current

    private var monthDays: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        var days: [Date] = []
        var cursor = interval.start
        while cursor < interval.end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    private var leadingBlanks: Int {
        guard let firstDay = monthDays.first else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstIndex = calendar.firstWeekday - 1
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7),
                  spacing: 10) {
            ForEach(weekdaySymbols.indices, id: \.self) { index in
                Text(weekdaySymbols[index])
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundStyle(palette.textFaint)
            }
            ForEach(0..<leadingBlanks, id: \.self) { _ in
                Color.clear.frame(height: 1)
            }
            ForEach(monthDays, id: \.self) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let daySessions = sessions.persisted.filter {
            calendar.isDate($0.startTime, inSameDayAs: day)
        }
        let hasSessions = !daySessions.isEmpty
        let isToday = calendar.isDateInToday(day)
        let isFuture = day > Date.now && !isToday
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        return Button {
            selectedDay = isSelected ? nil : day
        } label: {
            ZStack {
                Circle().fill(hasSessions ? ThemePalette.accent : palette.surface)
                if hasSessions {
                    Image("ShoeIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(ThemePalette.onAccent)
                } else {
                    Text("\(calendar.component(.day, from: day))")
                        .scaledFont(size: 15)
                        .foregroundStyle(palette.text)
                }
            }
            .overlay {
                if isToday {
                    Circle().strokeBorder(palette.text, lineWidth: 1.5)
                } else if isSelected {
                    Circle().strokeBorder(palette.accentText, lineWidth: 2)
                }
            }
            .opacity(isFuture ? 0.4 : 1)
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(!hasSessions)
        .accessibilityLabel(accessibilityLabel(day: day, hasSessions: hasSessions))
    }

    private func accessibilityLabel(day: Date, hasSessions: Bool) -> String {
        let dayLabel = day.formatted(.dateTime.day().month(.wide))
        return hasSessions ? "\(dayLabel), climbed" : dayLabel
    }
}
