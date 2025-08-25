//
//  GlobalInvariantsTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  Asserts high-level invariants across algorithms and sizes.
//  Keeps us from regressing on entrance/exit, connectivity, and door consistency.
//

import Testing
@testable import DungeonGrid

@Suite struct GlobalInvariantsTests {

    @Test("Lint invariants hold across seeds/algorithms")
    func entranceExitAndDoors() {
        let cfgs: [DungeonConfig] = [
            .init(width: 41, height: 25, algorithm: .bsp(BSPOptions()), ensureConnected: true, placeDoorsAndTags: true),
            .init(width: 41, height: 25, algorithm: .maze(MazeOptions()), ensureConnected: true, placeDoorsAndTags: true),
            .init(width: 41, height: 25, algorithm: .uniformRooms(UniformRoomsOptions()), ensureConnected: true, placeDoorsAndTags: true),
        ]
        let seeds: [UInt64] = [101, 202, 303]

        for cfg in cfgs {
            for s in seeds {
                let d = DungeonGrid.generate(config: cfg, seed: s)

                // If both are present, do a couple of quick sanity checks.
                if let a = d.entrance, let b = d.exit {
                    #expect(a != b)
                    #expect(d.grid[a.x, a.y].isPassable)
                    #expect(d.grid[b.x, b.y].isPassable)
                }

                // Rely on DungeonLint for the full set of invariants.
                let issues = DungeonLint.check(d)
                #expect(issues.isEmpty, "Lint issues for seed \(s) algo \(cfg.algorithm): \(issues)")
            }
        }
    }
}
