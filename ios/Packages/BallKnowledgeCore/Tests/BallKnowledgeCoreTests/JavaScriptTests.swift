import Foundation
import Testing
import BallKnowledgeCore

/// The JavaScript behaviours the port leans on, checked against what node itself answered.
/// The expected values below were printed by node v24 running the same expressions the web
/// game uses (`x.toFixed(1)`, `n.toLocaleString("en-US")`, `parseFloat`, `x >>> 0`, `Object.keys`,
/// `toLowerCase`, `split(/\\s+/)`, `String(x)` and the game's own one-line helpers); doubles
/// are given as their 64 bits so nothing is lost on the way in.
@Suite struct JavaScriptTests {
    static let node = #"""
{
"toFixed1":[["0","0.0"],["-0","0.0"],["0.04","0.0"],["0.05","0.1"],["0.06","0.1"],["0.25","0.3"],["0.75","0.8"],["0.35","0.3"],["0.15","0.1"],["1.25","1.3"],["2.5","2.5"],["51.9","51.9"],["34.1","34.1"],["20.4","20.4"],["9.95","9.9"],["9.949999","9.9"],["10.05","10.1"],["0.95","0.9"],["99.95","100.0"],["100.25","100.3"],["1e+21","1e+21"],["123456.75","123456.8"],["-0.04","-0.0"],["-0.25","-0.3"],["-1.25","-1.3"],["-51.9","-51.9"],["4.35","4.3"],["8.345","8.3"],["1.005","1.0"],["12.65","12.7"],["0.45","0.5"],["0.55","0.6"],["0.65","0.7"],["0.85","0.8"],["22.25","22.3"],["33.75","33.8"],["7.049999999999999","7.0"],["1e-7","0.0"],["5e-324","0.0"],["562949953421312.25","562949953421312.3"],["1125899906842624.25","1125899906842624.3"],["1125899906842624.75","1125899906842624.8"],["-1125899906842624.25","-1125899906842624.3"],["2251799813685248.5","2251799813685248.5"],["4503599627370495.5","4503599627370495.5"]],
"grouped":[[0,"0"],[1,"1"],[12,"12"],[123,"123"],[999,"999"],[1000,"1,000"],[1234,"1,234"],[9984,"9,984"],[12345,"12,345"],[123456,"123,456"],[999999,"999,999"],[1000000,"1,000,000"],[1234567,"1,234,567"],[1234567890,"1,234,567,890"],[-1,"-1"],[-999,"-999"],[-1000,"-1,000"],[-1234567,"-1,234,567"]],
"parseFloat":[["0","0"],["1","1"],["3.5","3.5"],["2","2"],["22/37","22"],["342","342"],["","NaN"],[" ","NaN"],["abc","NaN"],[".5","0.5"],["5.","5"],["-.5","-0.5"],["+3","3"],["-2.5e3","-2500"],["1e","1"],["1e+","1"],["1e5x","100000"],[" 12abc","12"],["\n\t7","7"],["Infinity","Infinity"],["-Infinity","-Infinity"],["+Infinity","Infinity"],["Infinityx","Infinity"],["infinity","NaN"],["0x10","0"],["1,000","1"],["1.2.3","1.2"],["..5","NaN"],["-","NaN"],["+","NaN"],[".","NaN"],["-.","NaN"],["1.e3","1000"],[".e3","NaN"],["0.0","0"],["-0","0"],["00012","12"],["1_000","1"],["\u00a04","4"],["\ufeff9","9"],["\uff11\uff12","NaN"],["1e400","Infinity"],["4e-400","0"]],
"toUint32":[["0",0],["1",1],["-1",4294967295],["1.9",1],["-1.9",4294967295],["-0.5",0],["4294967295",4294967295],["4294967296",0],["4294967297",1],["8589934591",4294967295],["-2147483648",2147483648],["2147483648",2147483648],["10000000000",1410065408],["-10000000000",2884901888],["1e+21",3735027712],["-1e+21",559939584],["9007199254740992",0],["0.999999",0],["NaN",0],["Infinity",0],["-Infinity",0],["16777215",16777215],["1.5",1],["255.9",255]],
"bits":[["0",0],["1",1],["-1",32],["1.9",1],["-1.9",32],["-0.5",0],["4294967295",32],["4294967296",0],["4294967297",1],["8589934591",32],["-2147483648",1],["2147483648",1],["10000000000",10],["-10000000000",13],["1e+21",8],["-1e+21",4],["9007199254740992",0],["0.999999",0],["NaN",0],["Infinity",0],["-Infinity",0],["16777215",24],["1.5",1],["255.9",8]],
"keys":[[["b","a","10","2","1","c","01","4294967294","4294967295","-1","1.5","0",""],["0","1","2","10","4294967294","b","a","c","01","4294967295","-1","1.5",""]],[["johnbrown","smokey","85","smoke","12","brown"],["12","85","johnbrown","smokey","smoke","brown"]],[["x"],["x"]]],
"pad2":[[5,"05"],[-5,"-5"],[12,"12"],[123,"123"],[0,"00"],[-12,"-12"]],
"parseHex":[["97233F","9904959"],["ffb612","16758290"],["0a0b0c","658188"],["","NaN"],["xyz","NaN"],["12xyz","18"],["0x1F","31"],[" ff","255"],["-ff","-255"],["+ff","255"],["FFFFFFFFFF","1099511627775"],["123456789ABCD","320255973501901"],["g","NaN"],["0","0"],["0x","NaN"],["ff ff","255"]],
"lower":[["\u039f\u0394\u03a5\u03a3\u03a3\u0395\u03a5\u03a3","\u03bf\u03b4\u03c5\u03c3\u03c3\u03b5\u03c5\u03c2"],["\u03a3\u039f\u03a6\u039f\u03a3","\u03c3\u03bf\u03c6\u03bf\u03c2"],["\u03a3","\u03c3"],["\u0391\u03a3","\u03b1\u03c2"],["\u0391\u03a3.","\u03b1\u03c2."],["\u0391\u03a3 \u0392","\u03b1\u03c2 \u03b2"],["\u0391\u03a3\u0392","\u03b1\u03c3\u03b2"],["\u0391.\u03a3","\u03b1.\u03c2"],["\u0130stanbul","i\u0307stanbul"],["STRASSE","strasse"],["\u1e9e","\u00df"],["\u01c5emal","\u01c6emal"],["\u0391\u03a3\u0301","\u03b1\u03c2\u0301"],["\u03a3\u0301\u0391","\u03c3\u0301\u03b1"],["A\u00ad\u03a3","a\u00ad\u03c2"],["\u03a3.\u03a3","\u03c3.\u03c2"],["a\u03a3","a\u03c2"],["1\u03a3","1\u03c3"],["\u0391\u03a31","\u03b1\u03c21"]],
"upper":[["#ffb612","#FFB612"],["stra\u00dfe","STRASSE"],["\u01c6","\u01c4"],["\u0149","\u02bcN"],["\u0131","I"],["\ufb01","FI"]],
"split":[["",[""]],[" ",["",""]],["a",["a"]],[" a",["","a"]],["a ",["a",""]],[" a b ",["","a","b",""]],["a  b",["a","b"]],["\u00a0a\ufeffb\u2028c",["","a","b","c"]],["a\u0085b",["a\u0085b"]],["a\u200bb",["a\u200bb"]],["a\u180eb",["a\u180eb"]],["a\u1680b",["a","b"]]],
"joinNice":[[[],""],[["#1"],"#1"],[["#1","#2"],"#1 and #2"],[["#1","#2","#3"],"#1, #2 and #3"]],
"an":[["quarterback","A quarterback"],["offensive lineman","An offensive lineman"],["inside linebacker","An inside linebacker"],["end","An end"],["umpire","A umpire"],["Apple","A Apple"],["","A "],["a","An a"]],
"num":[["0","0"],["9223372036854775808","0"],["4607182418800017408","1"],["13830554455654793216","-1"],["4602678819172646912","0.5"],["4609434218613702656","1.5"],["4636737291354636288","100"],["4728057454347157504","123456789"],["4845873199050653696","9007199254740992"],["4845873199050653697","9007199254740994"],["4877398396442247168","1152921504606847000"],["4906019910204099648","100000000000000000000"],["4907451598986591450","123456789012345680000"],["4921056587992461136","1e+21"],["4923652838987019132","1.5e+21"],["4922434392715952128","1.1805916207174113e+21"],["9094988921128908188","1e+300"],["9023551808715235066","1.6666666666666668e+295"],["4591870180066957722","0.1"],["4517329193108106637","0.000001"],["4502148214488346440","1e-7"],["4504762867522569078","1.5e-7"],["4517329193108106637","0.000001"],["4518434226865098134","0.000001234"],["4533401875807174908","0.00001234"],["1","5e-324"],["9218868437227405311","1.7976931348623157e+308"],["4629995965662416077","34.1"],["4632501092955140915","51.9"],["4599075939470750516","0.30000000000000004"],["4599676419421066581","0.3333333333333333"],["4636754883540680704","100.25"],["4751297606875873280","4294967296"],["4845873199050653696","9007199254740992"],["4846369599423283200","10000000000000000"],["4862380398305394688","120000000000000000"],["14144428624847236944","-1e+21"],["13861759897472843383","-123.456"],["13725520251343122248","-1e-7"],["9221120237041090560","NaN"],["9218868437227405312","Infinity"],["18442240474082181120","-Infinity"],["4892433759222981601","12345678901234567000"],["4921056587992461135","999999999999999900000"],["4928792221491993795","3.3333333333333335e+21"]],
"clock":[["0","0:00"],["4607182418800017408","0:01"],["4651998512748167168","0:01"],["4652007308841189376","0:01"],["4652016104934211584","0:02"],["4678341711838052352","0:59"],["4678341849277005824","1:00"],["4678479150791524352","1:00"],["4678616589744996352","1:01"],["4704983204996579328","59:59"],["4704985352480227328","60:00"],["4704985354627710976","60:01"],["13830554455654793216","0:00"],["13875379345695965184","0:00"],["4602678819172646912","0:01"],["4472406533629990549","0:01"],["4693401164257951744","10:00"],["4693401172847886336","10:00"],["4890698089091825664","150119987579016:32"],["4876203697187506176","16666666666666:40"],["4893729814446988160","250000000000000:00"],["4947601348598480987","1000000000000000000:00"],["4947720557888031768","1016666666666666600:40"],["4965913770331839924","16666666666666666000:40"],["9094988921128908188","1.6666666666666668e+295:36"],["9221120237041090560","NaN:NaN"],["9218868437227405312","Infinity:NaN"],["18442240474082181120","0:00"],["9218868437227405311","2.996155224770526e+303:48"]]
}
"""#

    static func vectors(_ name: String) throws -> [JSONValue] {
        let root = try #require(JSONValue(text: node), "the node vectors are JSON")
        let rows = root[name].list
        try #require(!rows.isEmpty, "node vectors for \(name)")
        return rows
    }

    /// A number from the text node printed for it.
    static func number(_ text: String) -> Double {
        switch text {
        case "NaN": .nan
        case "Infinity": .infinity
        case "-Infinity": -.infinity
        default: Double(text) ?? .nan
        }
    }

    static func sameNumber(_ a: Double, _ b: Double) -> Bool { a == b || (a.isNaN && b.isNaN) }

    static func bits(_ row: JSONValue) -> Double { Double(bitPattern: UInt64(row.text) ?? 0) }

    @Test func numbersAreWrittenTheWayJavaScriptWritesThem() throws {
        var t = Tally("node: number text")
        for row in try Self.vectors("num") {
            t.same(JS.numberText(Self.bits(row.list[0])), row.list[1].text, "String(\(row.list[1].text))")
        }
        for row in try Self.vectors("toFixed1") {
            let x = row.list[0].text == "-0" ? -0.0 : Self.number(row.list[0].text)
            t.same(JS.toFixed1(x), row.list[1].text, "(\(row.list[0].text)).toFixed(1)")
        }
        for row in try Self.vectors("grouped") {
            t.same(JS.groupedEnUS(Int(row.list[0].double)), row.list[1].text, "(\(row.list[0].double)).toLocaleString")
        }
        for row in try Self.vectors("pad2") {
            t.same(GameText.pad2(Int(row.list[0].double)), row.list[1].text, "pad2(\(row.list[0].double))")
        }
        for row in try Self.vectors("clock") {
            t.same(GameText.clockText(milliseconds: Self.bits(row.list[0])), row.list[1].text, "clockText(\(Self.bits(row.list[0])))")
        }
        t.finish()
    }

    @Test func numbersAreReadTheWayJavaScriptReadsThem() throws {
        var t = Tally("node: number reading")
        for row in try Self.vectors("parseFloat") {
            let got = JS.parseFloat(row.list[0].text), want = Self.number(row.list[1].text)
            t.same(Self.sameNumber(got, want), true, "parseFloat(\(Tally.show(row.list[0].text))) gave \(got), node \(want)")
        }
        for row in try Self.vectors("parseHex") {
            let got = JS.parseHex(row.list[0].text), want = Self.number(row.list[1].text)
            t.same(Self.sameNumber(got, want), true, "parseInt(\(Tally.show(row.list[0].text)), 16) gave \(got), node \(want)")
        }
        for row in try Self.vectors("toUint32") {
            let x = Self.number(row.list[0].text)
            t.same(Double(JS.toUInt32(x)), row.list[1].double, "\(row.list[0].text) >>> 0")
            var fromNumber = Mulberry32(seedNumber: x), fromSeed = Mulberry32(seed: UInt32(row.list[1].double))
            t.same(fromNumber.nextUInt32(), fromSeed.nextUInt32(), "rng(\(row.list[0].text))")
        }
        for row in try Self.vectors("bits") {
            let x = Self.number(row.list[0].text)
            t.same(Sequences.bits(ofNumber: x), Int(row.list[1].double), "bits(\(row.list[0].text))")
            if let n = Int(exactly: x) { t.same(Sequences.bits(n), Int(row.list[1].double), "bits(\(n)) as a whole number") }
        }
        t.finish()
    }

    @Test func textIsHandledTheWayJavaScriptHandlesIt() throws {
        var t = Tally("node: text")
        for row in try Self.vectors("lower") {
            t.same(JS.lowercased(row.list[0].text), row.list[1].text, "\(Tally.show(row.list[0].text)).toLowerCase()")
        }
        for row in try Self.vectors("upper") {
            t.same(JS.uppercased(row.list[0].text), row.list[1].text, "\(Tally.show(row.list[0].text)).toUpperCase()")
        }
        for row in try Self.vectors("split") {
            let pieces = JS.split(Array(row.list[0].text.unicodeScalars), on: JS.isWhiteSpace).map { String(String.UnicodeScalarView($0)) }
            t.same(pieces, row.list[1].list.map(\.text), "\(Tally.show(row.list[0].text)).split(/\\s+/)")
        }
        for row in try Self.vectors("keys") {
            var set = JSKeySet()
            for key in row.list[0].list { set.insert(key.text) }
            t.same(set.keys, row.list[1].list.map(\.text), "Object.keys after setting \(row.list[0].list.map(\.text))")
        }
        for row in try Self.vectors("joinNice") {
            t.same(GameText.joinNice(row.list[0].list.map(\.text)), row.list[1].text, "joinNice(\(row.list[0].list.map(\.text)))")
        }
        for row in try Self.vectors("an") {
            t.same(GameText.an(row.list[0].text), row.list[1].text, "an(\(row.list[0].text))")
        }
        t.finish()
    }

    /// `Number(text)` as node v24 answered it, and the line breaks a one-line text field drops.
    @Test func textIsTurnedIntoANumberTheWayNumberDoes() {
        let rows: [(String, String)] = [
            ("", "0"), (" ", "0"), ("7", "7"), (" 7 ", "7"), ("\t\n7\r\n", "7"), ("0x10", "16"), ("0X1f", "31"), ("0o17", "15"), ("0b101", "5"),
            ("-0x10", "NaN"), ("+7", "7"), ("-7.5e2", "-750"), (".5", "0.5"), ("5.", "5"), ("1e400", "Infinity"), ("-1e400", "-Infinity"),
            ("Infinity", "Infinity"), ("-Infinity", "-Infinity"), ("+Infinity", "Infinity"), ("infinity", "NaN"), ("1_000", "NaN"), ("12px", "NaN"),
            ("0x", "NaN"), ("1e", "NaN"), ("--1", "NaN"), ("\u{A0}7\u{2028}", "7"), ("\u{FEFF}7", "7"), ("00012", "12"), ("1e-400", "0"),
            ("9007199254740993", "9007199254740992"), ("0b", "NaN"), ("0.0000001", "1e-7")
        ]
        for (text, want) in rows { #expect(JS.numberText(JS.number(text)) == want, "Number(\(text.debugDescription))") }
        #expect(JS.textFieldValue("zz\nqq") == "zzqq")
        #expect(JS.textFieldValue("\r\n") == "")
        #expect(JS.textFieldValue("a\u{2028}b\tc") == "a\u{2028}b\tc")
    }

    @Test func textComparisonIsByCodeUnit() {
        // "é" as one scalar and as e plus an accent: equal to Swift, different to JavaScript.
        #expect("\u{E9}" == "e\u{301}")
        #expect(!JS.sameText("\u{E9}", "e\u{301}"))
        #expect(JS.sameText("abc", "abc"))
        #expect(JS.padStart("7", to: 2) == "07" && JS.padStart("123", to: 2) == "123" && JS.padStart("", to: 2) == "00")
        // An emoji is two UTF-16 units, so it already fills a width of two.
        #expect(JS.padStart("\u{1F3C8}", to: 2) == "\u{1F3C8}")
        #expect(JS.arrayIndex("0") == 0 && JS.arrayIndex("4294967294") == 4_294_967_294)
        #expect(JS.arrayIndex("4294967295") == nil && JS.arrayIndex("01") == nil && JS.arrayIndex("") == nil && JS.arrayIndex("-1") == nil)
    }
}

/// The golden comparisons are only as good as the comparing: this proves it tells apart text
/// that Swift's own `==` calls equal.
@Suite struct TallyTests {
    @Test func textIsComparedScalarByScalar() {
        // Nothing is reported until finish(), which this test never calls: it only reads the counts.
        var t = Tally("self-check")
        t.same("\u{E9}", "e\u{301}", "one string")
        t.same(["a", "\u{E9}"], ["a", "e\u{301}"], "a list of strings")
        t.same(Optional("\u{E9}"), Optional("e\u{301}"), "an optional string")
        #expect(t.compared == 4 && t.mismatches == 3 && t.notes.count == 3)
        t.same("\u{E9}", "\u{E9}", "the same text")
        t.same([1, 2], [1, 2], "numbers")
        t.same([String](), [String](), "an empty list counts once")
        #expect(t.compared == 8 && t.mismatches == 3)
        t.same([1, 2], [1], "a list of the wrong length is one difference")
        t.same(0.1 + 0.2, 0.3, "doubles are compared exactly")
        t.same(Optional<String>.none, Optional("x"), "nil against text")
        #expect(t.compared == 11 && t.mismatches == 6)
    }
}

extension JSONValue {
    /// The member of an object, `.null` when there is none.
    subscript(key: String) -> JSONValue {
        if case .object(let o) = self, let v = o[key] { return v }
        return .null
    }

    /// The elements of an array, empty for anything else.
    var list: [JSONValue] {
        if case .array(let a) = self { return a }
        return []
    }

    /// The text of a string, empty for anything else.
    var text: String {
        if case .string(let s) = self { return s }
        return ""
    }

    /// The value of a number, NaN for anything else.
    var double: Double {
        if case .number(let n) = self { return n }
        return .nan
    }
}
