//
//  FuzzInvariantsTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//

import Testing
@testable import DungeonGrid

@Suite struct FuzzInvariantsTests {

    @Test("DungeonLint holds across algos/seeds (small maps)")
    func lintAcrossSeeds() {
        // Keep run time modest; expand locally if you want.
        let seeds: [UInt64] = TestEnv.fuzzSeeds
        let cfgs: [DungeonConfig] = [
            .init(width: 41, height: 25, algorithm: .bsp(BSPOptions()),         ensureConnected: true, placeDoorsAndTags: true),
            .init(width: 41, height: 25, algorithm: .maze(MazeOptions()),        ensureConnected: true, placeDoorsAndTags: true),
            .init(width: 41, height: 25, algorithm: .uniformRooms(UniformRoomsOptions()), ensureConnected: true, placeDoorsAndTags: true),
        ]

        for cfg in cfgs {
            for s in seeds {
                let d = DungeonGrid.generate(config: cfg, seed: s)
                let issues = DungeonLint.check(d)
                #expect(issues.isEmpty, "Lint issues for seed \(s) algo \(cfg.algorithm): \(issues)")

                // If both S/E exist, sanity-assert we can route at region level
                if let a = d.entrance, let b = d.exit {
                    let index = DungeonIndex(d)
                    guard
                        let rs = Regions.regionID(at: a, labels: index.labels, width: index.width),
                        let rt = Regions.regionID(at: b, labels: index.labels, width: index.width)
                    else {
                        #expect(Bool(false), "Entrance/exit not in labeled regions")
                        continue
                    }
                    let route = RegionRouting.route(index.graph, from: rs, to: rt, doorBias: 0)
                    #expect(route != nil, "No region route between entrance and exit")
                }
            }
        }
    }
}
