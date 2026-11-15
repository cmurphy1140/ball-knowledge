import Foundation
import Testing
import BallKnowledgeCore

/// Area 9, home-board.json: every save string the web game stored or was handed. Each one is read
/// by `SaveState`, written back out, and compared with the original as parsed JSON, so a field
/// that changed name, type or value shows up. Text the web could not use is checked against the
/// save the web itself ended up holding.
@Suite struct SaveGoldenTests {
    struct StorageLoad: Decodable {
        let name: String
        let raw: String?
        let save: JSONValue
        let after: String?
        let rewritten: Bool
    }

    /// Every string under a `store`, `raw`, `after` or `ticketStore` key anywhere in the file.
    static func storedStrings(in value: JSONValue, path: String = "", into out: inout [(path: String, text: String)]) {
        switch value {
        case .object(let o):
            for (key, v) in o.sorted(by: { $0.key < $1.key }) {
                if ["store", "raw", "after", "ticketStore"].contains(key), case .string(let s) = v {
                    out.append((path + "." + key, s))
                } else {
                    storedStrings(in: v, path: path + "." + key, into: &out)
                }
            }
        case .array(let a):
            for (i, v) in a.enumerated() { storedStrings(in: v, path: path + "[\(i)]", into: &out) }
        default:
            break
        }
    }

    /// True for JSON with the six fields of a save, each of the kind the web writes.
    static func isSaveShaped(_ json: JSONValue) -> Bool {
        guard case .object(let o) = json, Set(o.keys) == ["known", "daily", "jm", "boom", "named", "live"] else { return false }
        for field in ["known", "daily", "jm", "boom", "named"] {
            guard case .object? = o[field] else { return false }
        }
        switch o["live"] {
        case .null?, .object?: return true
        default: return false
        }
    }

    /// Counts the leaves of a JSON value: the numbers, strings, booleans and nulls in it.
    static func leaves(_ json: JSONValue) -> Int {
        switch json {
        case .object(let o): max(1, o.values.reduce(0) { $0 + leaves($1) })
        case .array(let a): max(1, a.reduce(0) { $0 + leaves($1) })
        default: 1
        }
    }

    @Test func everyStoredSaveSurvivesTheRoundTrip() throws {
        let root = try #require(JSONValue(text: String(decoding: try Golden.data("home-board.json"), as: UTF8.self)))
        var strings: [(path: String, text: String)] = []
        Self.storedStrings(in: root, into: &strings)

        var shaped = 0, other = 0, values = 0, failures = 0
        for (path, text) in strings {
            guard let original = JSONValue(text: text), Self.isSaveShaped(original) else {
                // Text that is not a whole save is only ever something handed to the page at load
                // (and left as it was); the next test reads each of those the way the web did.
                other += 1
                #expect(path.hasPrefix(".storageLoad[") && (path.hasSuffix(".raw") || path.hasSuffix(".after")), "\(path) is not a whole save: \(text)")
                continue
            }
            shaped += 1
            let save = SaveState(storedText: text)
            let again = try #require(JSONValue(text: save.storedText()), "\(path): the re-encoded save is JSON")
            values += Self.leaves(original)
            if again != original {
                failures += 1
                if failures <= 5 { Issue.record("\(path): re-encoded save differs.\n  web:   \(text)\n  swift: \(save.storedText())") }
            }
            // Reading what was written gives the same save again, by either route.
            #expect(SaveState(storedText: save.storedText()) == save)
            #expect(try JSONDecoder().decode(SaveState.self, from: Data(text.utf8)) == save)
        }
        print("GOLDEN home-board.json (stored saves): \(strings.count) strings, \(shaped) save-shaped ones round-tripped, \(values) values compared, \(failures) differ; \(other) are not whole saves, all of them text handed to the page at load (read in the next test)")
        #expect(failures == 0)
        #expect(shaped >= 100, "the file holds the web's stored saves")
    }

    @Test func storedTextIsReadTheWayTheWebReadsIt() throws {
        struct File: Decodable { let storageLoad: [StorageLoad] }
        let file = try Golden.load(File.self, from: "home-board.json")
        var compared = 0, skipped: [String] = []
        for row in file.storageLoad {
            // When the page rewrote its storage on load, `save` already shows what start() did next
            // (a stale round dropped, an expired one settled). That step belongs to the home logic;
            // here only the reading is under test, so those rows are left to it.
            if row.rewritten { skipped.append(row.name); continue }
            // The page left its storage alone, so what it holds afterwards is still the raw text.
            #expect(row.after == row.raw, "\(row.name): not rewritten")
            let save = SaveState(storedText: row.raw)
            let got = try #require(JSONValue(text: save.storedText()))
            compared += Self.leaves(row.save)
            #expect(got == row.save, "\(row.name): raw \(row.raw ?? "nil") read as \(save.storedText())")
        }
        print("GOLDEN home-board.json (storageLoad): \(file.storageLoad.count - skipped.count) of \(file.storageLoad.count) raw strings read and compared with the web's save, \(compared) values; \(skipped.count) left for the home logic because the page changed the save after reading it: \(skipped)")
        #expect(file.storageLoad.count - skipped.count >= 18)
    }
}

/// The save model away from the golden files: the shape it writes and what it forgives.
@Suite struct SaveStateTests {
    @Test func anEmptySaveWritesTheWebsEmptyShape() throws {
        let text = SaveState().storedText()
        #expect(JSONValue(text: text) == JSONValue(text: #"{"known":{},"daily":{},"jm":{},"boom":{},"named":{},"live":null}"#))
        #expect(SaveState.storageKey == "ballknowledge.v1")
    }

    @Test func aFullSaveWritesEveryFieldWithTheWebsNamesAndTypes() throws {
        var save = SaveState()
        save.known["2019KC"] = 0b101
        save.daily[35] = LineupRecord(key: "2014JAX", daily: 35, over: true, reason: "time", endAt: 1_794_675_599_000,
                                      states: [1, 2, 3] + Array(repeating: 3, count: 21), clues: [0, 1] + Array(repeating: 0, count: 22))
        save[.journeyman][35] = QuizRecord(target: 602, guesses: [1, 2, 602], over: true, won: true)
        save[.boxScore][-2] = QuizRecord(target: 17, guesses: [5])
        save.live = LineupRecord(key: "2022PIT", unit: "off", timed: false, daily: 36, states: Array(repeating: 0, count: 24), clues: Array(repeating: 0, count: 24))
        let want = #"""
        {"known":{"2019KC":5},
         "daily":{"35":{"key":"2014JAX","unit":"all","timed":true,"daily":35,"over":true,"reason":"time","endAt":1794675599000,
                        "st":[1,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],"cl":[0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]}},
         "jm":{"35":{"t":602,"g":[1,2,602],"over":true,"won":true}},
         "boom":{"-2":{"t":17,"g":[5],"over":false,"won":false}},
         "named":{},
         "live":{"key":"2022PIT","unit":"off","timed":false,"daily":36,"over":false,"reason":"","endAt":0,
                 "st":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"cl":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]}}
        """#
        #expect(JSONValue(text: save.storedText()) == JSONValue(text: want))
        #expect(SaveState(storedText: save.storedText()) == save)
        #expect(SaveState(storedText: want) == save)
    }

    @Test func garbageNeverFailsAndNeverInventsProgress() {
        let empty = SaveState()
        for text in ["", "{bad", "null", "42", "\"x\"", "[]", "{}", "true", "[1,2,3]", "{\"known\":5}", "{\"known\":\"abc\",\"daily\":[1],\"jm\":true,\"live\":7}",
                     "{\"daily\":{\"35\":\"junk\",\"x\":{},\"36\":{\"key\":\"2019KC\"}}}", "{\"jm\":{\"1\":{\"g\":[1]},\"2\":null}}", "{\"live\":{\"key\":5,\"st\":[],\"cl\":[]}}"] {
            #expect(SaveState(storedText: text) == empty, "\(text) reads as an empty save")
        }
        #expect(SaveState(storedText: nil) == empty)
    }

    @Test func whatTheWebTreatsAsOptionalIsOptional() {
        // An older quiz record files its answer under `i`; `t` wins when both are there.
        let legacy = SaveState(storedText: #"{"jm":{"3":{"i":44,"g":[9]},"4":{"t":7,"i":8,"over":1,"won":"yes"},"5":{"t":null,"i":2}}}"#)
        #expect(legacy.journeyman[3] == QuizRecord(target: 44, guesses: [9]))
        #expect(legacy.journeyman[4] == QuizRecord(target: 7, guesses: [], over: true, won: true))
        #expect(legacy.journeyman[5] == QuizRecord(target: 2))

        // A round needs only its lineup and the two arrays; the rest falls back as newGame does.
        let bare = SaveState(storedText: #"{"live":{"key":"2019KC","st":[1,0],"cl":[true,0]},"daily":{"7":{"key":"2020GB","st":[],"cl":[],"over":true}}}"#)
        #expect(bare.live == LineupRecord(key: "2019KC", unit: "all", timed: true, daily: 0, over: false, reason: "", endAt: 0, states: [1, 0], clues: [1, 0]))
        #expect(bare.daily[7]?.over == true)

        // Days the game cannot look up are left out. A mask is read the way the web's bit count
        // reads it (ToNumber, then 32 bits), so the text "7" is 7, as it is on the web; a stored 0
        // stays (the web writes it back), and other values that read as false are not there.
        let odd = SaveState(storedText: #"{"known":{"2019KC":7.9,"2020KC":"7","2021KC":-1,"2022KC":4294967296,"2023KC":"","2024KC":0},"named":{"07":{"t":1},"1.0":{"t":1},"8":{"t":1}}}"#)
        #expect(odd.known == ["2019KC": 7, "2020KC": 7, "2021KC": -1, "2022KC": 4_294_967_296, "2024KC": 0])
        #expect(Array(odd.namedGame.keys) == [8])
        // Unknown top-level fields are dropped, as the web drops them.
        let extra = SaveState(storedText: #"{"v":2,"known":{"2019KC":7},"extra":{"a":1}}"#)
        #expect(JSONValue(text: extra.storedText()) == JSONValue(text: #"{"known":{"2019KC":7},"daily":{},"jm":{},"boom":{},"named":{},"live":null}"#))
    }

    @Test func storedTextIsParsedTheWayJSONParseParsesIt() {
        // A number too big for a double is infinity, not a broken save; it is written back as null, as JSON.stringify does.
        let big = SaveState(storedText: #"{"known":{"2014ARI":1e400,"2019KC":3},"daily":{"35":{"key":"2019KC","st":[1],"cl":[0],"endAt":1e400}}}"#)
        #expect(big.known == ["2014ARI": .min, "2019KC": 3])
        #expect(big.daily[35]?.endAt == .infinity)
        #expect(JSONValue(text: big.storedText())?["known"]?["2014ARI"] == .null)
        #expect(JSONValue(text: big.storedText())?["daily"]?["35"]?["endAt"] == .null)
        // The last of two equal keys wins; a byte-order mark is not white space, so that text is no save at all.
        #expect(SaveState(storedText: #"{"known":{"2014ARI":3,"2014ARI":0}}"#).known == ["2014ARI": 0])
        #expect(SaveState(storedText: "\u{FEFF}{\"known\":{\"2014ARI\":3}}") == SaveState())
        #expect(SaveState(storedText: " \t\n{\"known\":{\"2014ARI\":3}}\r\n").known == ["2014ARI": 3])
        // Values that are not quite right are read as the page reads them, not dropped with their
        // record: a state is compared with ===, so 1.5 and "1" are neither found nor open.
        let loose = SaveState(storedText: #"{"jm":{"4":{"t":"12","g":[1,"x"],"over":0}},"live":{"key":"2019KC","st":[1.5,"1",2],"cl":"yes","endAt":"0"}}"#)
        #expect(loose.journeyman[4] == QuizRecord(target: 12, guesses: [1, -1]))
        #expect(loose.live?.states == [-1, -1, 2])
        #expect(loose.live?.clues == [1, 1, 1])
        #expect((loose.live?.endAt ?? 0) > 0)
    }

    @Test func aStoreIsReadAndWrittenWithoutEverThrowing() {
        let store = MemorySaveStore()
        #expect(SaveState(loadingFrom: store) == SaveState())
        var save = SaveState()
        save.known["2014SEA"] = 0xFFFFFF
        save.persist(to: store)
        #expect(store.writes == 1)
        #expect(SaveState(loadingFrom: store) == save)
        #expect(JSONValue(text: store.text ?? "") == JSONValue(text: #"{"known":{"2014SEA":16777215},"daily":{},"jm":{},"boom":{},"named":{},"live":null}"#))

        // A store that refuses: nothing is read, nothing is written, nothing is thrown.
        store.failing = true
        #expect(SaveState(loadingFrom: store) == SaveState())
        SaveState().persist(to: store)
        store.failing = false
        #expect(SaveState(loadingFrom: store) == save)
    }

    @Test func sideGamesFileUnderTheWebsNames() {
        #expect(SideGame.allCases.map(\.rawValue) == ["jm", "boom", "named"])
        var save = SaveState()
        for game in SideGame.allCases { save[game][1] = QuizRecord(target: 1) }
        #expect(save.journeyman.count == 1 && save.boxScore.count == 1 && save.namedGame.count == 1)
    }
}
