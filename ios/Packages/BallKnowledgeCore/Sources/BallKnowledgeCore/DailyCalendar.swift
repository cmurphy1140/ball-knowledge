import Foundation

/// A calendar date as the player's wall clock reads it: Gregorian year, month 1 to 12, day.
public struct LocalDay: Sendable, Hashable {
    /// The Gregorian year, for example 2026.
    public let year: Int
    /// The month, 1 for January to 12 for December.
    public let month: Int
    /// The day of the month, from 1.
    public let day: Int

    /// A date from its parts.
    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The date an instant falls on in a calendar's time zone. Only the time zone of `calendar` is
    /// used; the date is always read on the Gregorian calendar, as the web reads it, whatever
    /// calendar the device is set to.
    public init(_ date: Date, calendar: Calendar) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let c = gregorian.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    /// Days since 1970-01-01 on the proleptic Gregorian calendar (negative before it).
    /// The same count `Date.UTC(year, month - 1, day) / 864e5` gives.
    package var daysSinceEpoch: Int {
        // Normalise the month first, as Date.UTC does for a month outside 1...12.
        let m0 = month - 1
        let y = year + Int((Double(m0) / 12).rounded(.down))
        let m = ((m0 % 12) + 12) % 12 + 1
        let yy = m <= 2 ? y - 1 : y
        let era = (yy >= 0 ? yy : yy - 399) / 400
        let yoe = yy - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468 + (day - 1)
    }

    /// Day of the week, 0 for Sunday to 6 for Saturday.
    package var weekday: Int {
        ((daysSinceEpoch % 7) + 11) % 7
    }
}

/// The daily schedule: which day number a date is, and how the date reads on the home screen.
/// Web: `dayNo`, `todayText`.
public enum DailyCalendar {
    /// The date that is day 1: 11 October 2026.
    public static let firstDay = LocalDay(year: 2026, month: 10, day: 11)

    /// The daily number of a local date: whole days since the first day, plus one. It depends only
    /// on the calendar date, never on the time of day or the time zone offset. Web: `dayNo()`.
    public static func dayNumber(of day: LocalDay) -> Int {
        day.daysSinceEpoch - firstDay.daysSinceEpoch + 1
    }

    /// The daily number at an instant, on the wall clock of `calendar`'s time zone.
    public static func dayNumber(at date: Date, calendar: Calendar) -> Int {
        dayNumber(of: LocalDay(date, calendar: calendar))
    }

    private static let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// The date as the home screen shows it, for example `Sat, Nov 14`: always in US English,
    /// whatever the device language, as the web asks for. Web: `todayText()`.
    public static func todayText(for day: LocalDay) -> String {
        let month = months[((day.month - 1) % 12 + 12) % 12]
        return weekdays[day.weekday] + ", " + month + " " + String(day.day)
    }

    /// The home screen date at an instant, on the wall clock of `calendar`'s time zone.
    public static func todayText(at date: Date, calendar: Calendar) -> String {
        todayText(for: LocalDay(date, calendar: calendar))
    }
}
