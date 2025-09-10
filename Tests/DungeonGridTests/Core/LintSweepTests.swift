//
//  LintSweepTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  Runs DungeonLint across a few seeds & algorithms to catch regressions.
//

import Testing
@testable import DungeonGrid

@Suite struct LintSweepTests {

    @Test("DungeonLint reports no issues across seeds/algos")
    func sweep() {
        let cfgs: [DungeonConfig] = [
            .init(width: 41, height: 25, algorithm: .bsp(BSPOptions()), ensureConnected: true, placeDoorsAndTags: true),
            .init(width: 41, height: 25, algorithm: .maze(MazeOptions()), ensureConnected: true, placeDoorsAndTags: true),
            .init(width: 41, height: 25, algorithm: .uniformRooms(UniformRoomsOptions()), ensureConnected: true, placeDoorsAndTags: true),
        ]
        let seeds: [UInt64] = TestEnv.fuzzSeeds

        for cfg in cfgs {
            for s in seeds {
                let d = DungeonGrid.generate(config: cfg, seed: s)
                let issues = DungeonLint.check(d)
                if !issues.isEmpty {
                    TestDebug.print(d)
                }
                #expect(issues.isEmpty)
            }
        }
    }
}
