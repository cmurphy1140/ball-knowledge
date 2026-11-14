import Foundation
import Testing
import BallKnowledgeCore

/// The app builds everything at launch, so reading data.json and building every table has a budget.
@Suite struct LoadTimeTests {
    /// The budget for reading the file and building everything, in a release build on this Mac.
    static let budget: Duration = .milliseconds(150)

    @Test func loadingAndBuildingEverythingFitsTheBudget() throws {
        let clock = ContinuousClock()
        var runs: [Duration] = []
        var bytes = 0
        for _ in 0..<9 {
            var built: GameData?
            let took = try clock.measure {
                // The whole job each time: the file off the disk, the JSON read, every derived table.
                let json = try Data(contentsOf: Repo.dataURL)
                bytes = json.count
                built = try GameData(json: json)
            }
            runs.append(took)
            let data = try #require(built)
            #expect(data.players.count == 3020 && data.lineups.count == 416 && data.dailyLineupOrder.count == 416)
        }
        func ms(_ d: Duration) -> String {
            let c = d.components
            return String(format: "%.1f ms", Double(c.seconds) * 1000 + Double(c.attoseconds) / 1e15)
        }
        let sorted = runs.sorted()
        let median = sorted[sorted.count / 2]
        #if DEBUG
        let build = "debug build, budget not enforced"
        #else
        let build = "release build, budget \(ms(Self.budget)) enforced on every run"
        #endif
        print("LOAD data.json (\(bytes) bytes) read and every table built: first \(ms(runs[0])), median \(ms(median)), fastest \(ms(sorted[0])), slowest \(ms(sorted[sorted.count - 1])) over \(runs.count) runs (\(build))")
        #if !DEBUG
        #expect(sorted[sorted.count - 1] < Self.budget, "the slowest of \(runs.count) runs took \(ms(sorted[sorted.count - 1]))")
        #endif
    }
}
