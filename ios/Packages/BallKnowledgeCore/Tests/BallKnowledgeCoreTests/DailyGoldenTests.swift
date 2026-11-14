import Foundation
import Testing
import BallKnowledgeCore

/// Area 5, daily.json: the daily orders, day numbers by date and time zone, the daily pick for
/// 1,506 days, the clock text, the home screen date and the picker's starting lineup.
@Suite struct DailyGoldenTests {
    struct File: Decodable {
        struct ByDay: Decodable {
            let from: Int, to: Int
            let lineup: [String], jm: [Int], boom: [Int], named: [Int]
        }
        struct DayNo: Decodable { let tz: String, ms: Double, ymd: [Int], hm: [Int], n: Int }
        struct SameInstant: Decodable { let tz: String, ms: Double, ymd: [Int], hm: [Int], n: Int, today: String }
        struct Clock: Decodable { let ms: Double, text: String }
        struct Today: Decodable { let tz: String, ms: Double, ymd: [Int], text: String, n: Int }
        struct Picker: Decodable {
            let tz: String, ms: Double, ymd: [Int], hash: String, n: Int, team: String, year: Int, ticket: String, sub: String
        }
        let epoch: [Int]
        let zones: [String]
        let order: [String]
        let jpool: [Int], jdaily: [Int], bdaily: [Int], ndaily: [Int]
        let byDay: ByDay
        let dayNo: [DayNo]
        let sameInstant: [SameInstant]
        let clock: [Clock]
        let today: [Today]
        let picker: [Picker]
    }

    /// A Gregorian calendar on one zone's wall clock.
    static func calendar(_ zone: String) throws -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = try #require(TimeZone(identifier: zone), "this Mac knows the zone \(zone)")
        return c
    }

    static func date(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }

    @Test func everyValueMatchesTheWeb() throws {
        let file = try Golden.load(File.self, from: "daily.json")
        let data = try Repo.gameData()
        var t = Tally("daily.json")

        let first = DailyCalendar.firstDay
        t.same([first.year, first.month, first.day], file.epoch, "epoch")
        t.same(DailyCalendar.dayNumber(of: first), 1, "the epoch is day 1")
        for z in file.zones { t.same(TimeZone(identifier: z) != nil, true, "zone \(z) exists") }

        t.same(data.dailyLineupOrder.map(\.rawValue), file.order, "DAILY_ORDER")
        t.same(data.journeymanPool, file.jpool, "JPOOL")
        t.same(data.journeymanDailyOrder, file.jdaily, "JDAILY")
        t.same(data.boxScoreDailyOrder, file.bdaily, "BDAILY")
        t.same(data.namedGameDailyOrder, file.ndaily, "NDAILY")
        t.same(data.dailyOrder(for: .journeyman), file.jdaily, "QZ.jm.order")
        t.same(data.dailyOrder(for: .boxScore), file.bdaily, "QZ.boom.order")
        t.same(data.dailyOrder(for: .namedGame), file.ndaily, "QZ.named.order")

        let days = Array(file.byDay.from...file.byDay.to)
        t.same(days.map { data.dailyLineup(day: $0).rawValue }, file.byDay.lineup, "dailyKey(n)")
        t.same(days.map { data.dailyTarget(for: .journeyman, day: $0) ?? -1 }, file.byDay.jm, "qDaily(jm, n)")
        t.same(days.map { data.dailyTarget(for: .boxScore, day: $0) ?? -1 }, file.byDay.boom, "qDaily(boom, n)")
        t.same(days.map { data.dailyTarget(for: .namedGame, day: $0) ?? -1 }, file.byDay.named, "qDaily(named, n)")

        // dayNo: from the wall-clock date the file gives, and again from the instant and the zone,
        // which also proves this Mac's time zone rules put the instant on the same date and minute.
        var calendars: [String: Calendar] = [:]
        for z in file.zones { calendars[z] = try Self.calendar(z) }
        for row in file.dayNo {
            let cal = try #require(calendars[row.tz]), date = Self.date(row.ms), what = "dayNo at \(row.ms) in \(row.tz)"
            let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            t.same([c.year ?? 0, c.month ?? 0, c.day ?? 0], row.ymd, what + " local date")
            t.same([c.hour ?? -1, c.minute ?? -1], row.hm, what + " local time")
            let local = LocalDay(date, calendar: cal)
            t.same([local.year, local.month, local.day], row.ymd, what + " LocalDay")
            t.same(DailyCalendar.dayNumber(of: LocalDay(year: row.ymd[0], month: row.ymd[1], day: row.ymd[2])), row.n, what + " from the date")
            t.same(DailyCalendar.dayNumber(at: date, calendar: cal), row.n, what + " from the instant")
        }
        for row in file.sameInstant {
            let cal = try #require(calendars[row.tz]), date = Self.date(row.ms), what = "instant \(row.ms) in \(row.tz)"
            let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            t.same([c.year ?? 0, c.month ?? 0, c.day ?? 0], row.ymd, what + " local date")
            t.same([c.hour ?? -1, c.minute ?? -1], row.hm, what + " local time")
            t.same(DailyCalendar.dayNumber(at: date, calendar: cal), row.n, what + " dayNo")
            t.same(DailyCalendar.todayText(at: date, calendar: cal), row.today, what + " todayText")
        }

        for row in file.clock {
            t.same(GameText.clockText(milliseconds: row.ms), row.text, "clockText(\(row.ms))")
        }

        for row in file.today {
            let cal = try Self.calendar(row.tz), date = Self.date(row.ms), what = "today at \(row.ms) in \(row.tz)"
            let local = LocalDay(date, calendar: cal)
            t.same([local.year, local.month, local.day], row.ymd, what + " local date")
            t.same(DailyCalendar.todayText(at: date, calendar: cal), row.text, what + " todayText")
            t.same(DailyCalendar.todayText(for: LocalDay(year: row.ymd[0], month: row.ymd[1], day: row.ymd[2])), row.text, what + " todayText from the date")
            t.same(DailyCalendar.dayNumber(at: date, calendar: cal), row.n, what + " dayNo")
        }

        // The picker on a fresh page load: nothing saved, so every ticket reads untouched.
        let fresh = SaveState()
        for row in file.picker {
            let cal = try Self.calendar(row.tz), date = Self.date(row.ms), what = "picker at \(row.ymd) with \(Tally.show(row.hash))"
            let local = LocalDay(date, calendar: cal)
            t.same([local.year, local.month, local.day], row.ymd, what + " local date")
            let n = DailyCalendar.dayNumber(at: date, calendar: cal)
            t.same(n, row.n, what + " dayNo")
            let key = data.defaultPickerLineup(day: n, anchor: row.hash)
            t.same(key.team.rawValue, row.team, what + " team")
            t.same(key.year, row.year, what + " year")
            t.same(key.label, row.ticket, what + " ticket title")
            t.same(LineupPicker.ticketSubtitle(mask: fresh.known[key.rawValue] ?? 0, year: key.year), row.sub, what + " ticket sub line")
        }
        #expect(file.dayNo.count == 3150 && file.sameInstant.count == 126 && file.clock.count == 65 && file.today.count == 27 && file.picker.count == 31)
        t.finish()
    }

    @Test func theDeviceCalendarDoesNotChangeTheDay() throws {
        // A device set to the Buddhist or Japanese calendar still plays the same day as everyone else.
        let zone = try #require(TimeZone(identifier: "America/New_York"))
        let noon = Date(timeIntervalSince1970: 1_794_675_600)   // 14 November 2026, 12:00 in New York
        for id in [Calendar.Identifier.gregorian, .buddhist, .japanese, .hebrew, .islamicUmmAlQura, .iso8601] {
            var cal = Calendar(identifier: id)
            cal.timeZone = zone
            #expect(DailyCalendar.dayNumber(at: noon, calendar: cal) == 35)
            #expect(DailyCalendar.todayText(at: noon, calendar: cal) == "Sat, Nov 14")
        }
    }

    @Test func anchorsNameALineupOnlyWhenWhole() {
        #expect(LineupPicker.lineup(fromAnchor: "#jax-2017") == LineupKey(year: 2017, team: .jax))
        #expect(LineupPicker.lineup(fromAnchor: "KC2019") == LineupKey(year: 2019, team: .kc))
        #expect(LineupPicker.lineup(fromAnchor: "#jax-2017 ") == nil)
        #expect(LineupPicker.lineup(fromAnchor: "##kc-2019") == nil)
        #expect(LineupPicker.lineup(fromAnchor: "#kc-２０１９") == nil)
        #expect(LineupPicker.lineup(fromAnchor: "") == nil)
        #expect(LineupPicker.ticketSubtitle(mask: 0b111, year: 2019) == "3 of 24 named so far.")
        #expect(LineupPicker.ticketSubtitle(mask: 0xFFFFFF, year: 2026) == "All 24 named. Run it back. Season in progress.")
    }
}
