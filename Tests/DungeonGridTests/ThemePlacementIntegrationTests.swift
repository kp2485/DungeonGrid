//
//  ThemePlacementIntegrationTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Testing
@testable import DungeonGrid

@Suite struct ThemePlacementIntegrationTests {

    @Test("Theme-name filter + determinism")
    func themeFilterAndDeterminism() {
        // Generate and theme
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39,
                          algorithm: .uniformRooms(UniformRoomsOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: 1234
        )
        let g = Regions.extractGraph(d)
        let s = RegionAnalysis.computeStats(dungeon: d, graph: g)

        // Theme rules: mark some far, bigger rooms as 'treasure'; fallbacks for other regions
        let rules: [ThemeRule] = [
            ThemeRule(regionClass: .room,minArea: 16, minDistanceFromEntrance: 4,
                      options: [Theme("treasure")]),
            ThemeRule(regionClass: .room, options: [Theme("room")]),
            ThemeRule(regionClass: .corridor, options: [Theme("corridor")]),
        ]
        let assignment = Themer.assignThemes(dungeon: d, graph: g, stats: s, seed: 99, rules: rules)

        // Plan treasure only in regions themed 'treasure'
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
        #expect(plan1 == plan2) // deterministic

        // Every placement must be in a region themed 'treasure'
        let (labels, _, w, _) = Regions.labelCells(d)
        for p in plan1.placements {
            let rid = labels[p.position.y * w + p.position.x]
            #expect(rid != nil)
            let th = assignment.regionToTheme[rid!]
            #expect(th?.name == "treasure")
            #expect(p.kind == "loot.treasure")
        }
    }

    @Test("Cross-kind spacing: no overlapping tiles across specs")
    func noOverlapAcrossSpecs() {
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39,
                          algorithm: .bsp(BSPOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: 202
        )
        let g = Regions.extractGraph(d)
        let s = RegionAnalysis.computeStats(dungeon: d, graph: g)
        // Simple theming so all regions have a theme
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

        let index = DungeonIndex(d)
        let plan = ContentPlanner.planAll(in: d, index: index, themes: themes, seed: 9, specs: specs)
        // Ensure no exact-tile overlaps across kinds
        var seen = Set<Int>()
        for p in plan.placements {
            let li = p.position.y * d.grid.width + p.position.x
            #expect(!seen.contains(li))
            seen.insert(li)
        }
    }
}
