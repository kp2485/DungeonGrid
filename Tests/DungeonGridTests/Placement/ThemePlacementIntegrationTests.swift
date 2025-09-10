//
//  ThemePlacementIntegrationTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Testing
@testable import DungeonGrid

@Suite struct ThemePlacementIntegrationTests {

    @Test("Theme-name filter + determinism (first two fuzz seeds)")
    func themeFilterAndDeterminism() {
        let seeds = Array(TestEnv.fuzzSeeds.prefix(2))
        for worldSeed in seeds {
            let d = DungeonGrid.generate(
                config: .init(width: 61, height: 39,
                              algorithm: .uniformRooms(UniformRoomsOptions()),
                              ensureConnected: true, placeDoorsAndTags: true),
                seed: worldSeed
            )
            let index = DungeonIndex(d)
            let g = index.graph
            let s = RegionAnalysis.computeStats(dungeon: d, graph: g)

            let rules: [ThemeRule] = [
                ThemeRule(regionClass: .room, minArea: 16, minDistanceFromEntrance: 4,
                          options: [Theme("treasure")]),
                ThemeRule(regionClass: .room, options: [Theme("room")]),
                ThemeRule(regionClass: .corridor, options: [Theme("corridor")]),
            ]
            let assignment = Themer.assignThemes(dungeon: d, graph: g, stats: s, seed: 99, rules: rules)

            var pol = PlacementPolicy()
            pol.count = 10
            pol.regionClass = .roomsOnly
            pol.minSpacing = 2

            let specs = [
                SpawnSpec(kind: "loot.treasure",
                          themeNames: ["treasure"],
                          policy: pol)
            ]

            let plan1 = ContentPlanner.planAll(in: d, graph: g, themes: assignment, seed: 777, specs: specs)
            let plan2 = ContentPlanner.planAll(in: d, graph: g, themes: assignment, seed: 777, specs: specs)
            #expect(plan1 == plan2, "ContentPlanner determinism failed for worldSeed \(worldSeed)")

            let (labels, _, w, _) = Regions.labelCells(d)
            for p in plan1.placements {
                let rid = labels[p.position.y * w + p.position.x]
                #expect(rid != nil, "Placement at \(p.position) not labeled (seed \(worldSeed))")
                let th = rid.flatMap { assignment.regionToTheme[$0] }
                #expect(th?.name == "treasure", "Non-treasure placement at \(p.position) (seed \(worldSeed))")
                #expect(p.kind == "loot.treasure", "Wrong kind at \(p.position): \(p.kind) (seed \(worldSeed))")
            }
        }
    }

    @Test("Cross-kind spacing: no overlapping tiles across specs")
    func noOverlapAcrossSpecs() {
        guard let worldSeed = TestEnv.fuzzSeeds.first else { return }
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39,
                          algorithm: .bsp(BSPOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: worldSeed
        )
        let index = DungeonIndex(d)
        let g = index.graph
        let s = RegionAnalysis.computeStats(dungeon: d, graph: g)

        let rules: [ThemeRule] = [
            ThemeRule(regionClass: .room, options: [Theme("room")]),
            ThemeRule(regionClass: .corridor, options: [Theme("corridor")])
        ]
        let themes = Themer.assignThemes(dungeon: d, graph: g, stats: s, seed: 1, rules: rules)

        var A = PlacementPolicy(); A.count = 25; A.minSpacing = 2; A.regionClass = .roomsOnly
        var B = PlacementPolicy(); B.count = 25; B.minSpacing = 2; B.regionClass = .corridorsOnly

        let specs = [
            SpawnSpec(kind: "enemy", themeNames: ["room","corridor"], policy: A),
            SpawnSpec(kind: "loot",  themeNames: ["room","corridor"], policy: B),
        ]

        let plan = ContentPlanner.planAll(in: d,
                                          graph: g,
                                          themes: themes,
                                          seed: d.seed,
                                          specs: specs)

        var seen = Set<Int>()
        for p in plan.placements {
            let li = p.position.y * d.grid.width + p.position.x
            #expect(!seen.contains(li), "Overlapping placement at \(p.position)")
            seen.insert(li)
        }
    }
}
