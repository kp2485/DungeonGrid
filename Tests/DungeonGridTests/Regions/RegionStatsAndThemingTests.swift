//
//  RegionStatsAndThemingTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Testing
@testable import DungeonGrid

@Suite struct RegionStatsAndThemingTests {

    @Test("Stats: counts & degrees are sane; distances defined when entrance exists")
    func statsSane() {
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39, algorithm: .uniformRooms(UniformRoomsOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: 101
        )
        let g = Regions.extractGraph(d)
        let s = RegionAnalysis.computeStats(dungeon: d, graph: g)

        // We should have stats for all nodes
        #expect(s.nodes.count == g.nodes.count)

        // Degrees are >= 0, dead-end implies degree == 1
        for (rid, st) in s.nodes {
            #expect(st.degree >= 0)
            if st.isDeadEnd { #expect(st.degree == 1) }
            // Area matches node tileCount
            let n = g.nodes[rid]!
            #expect(st.area == n.tileCount)
            // If entrance exists, some regions should have finite distance
        }
        if d.entrance != nil {
            #expect(s.nodes.values.contains(where: { $0.distanceFromEntrance != nil }))
        }
    }

    @Test("Theming: dead-end corridors and large rooms get themed (when present)")
    func themingRulesApply() {
        // Use an algo that creates rooms + corridors
        let d = DungeonGrid.generate(
            config: .init(width: 41, height: 25,
                          algorithm: .uniformRooms(UniformRoomsOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: 33
        )
        let g = Regions.extractGraph(d)
        let s = RegionAnalysis.computeStats(dungeon: d, graph: g)

        // Rules:
        // 1) Dead-end corridors -> "dead_end" (if any exist)
        // 2) Big rooms (area >= 20) with degree >= 2 -> "hub"
        // 3) Fallback for rooms -> "room"
        // 4) Fallback for corridors -> "corridor"
        let rules: [ThemeRule] = [
            ThemeRule(regionClass: .corridor,
                      deadEndOnly: true,
                      options: [Theme("dead_end")]),
            ThemeRule(regionClass: .room,
                      minArea: 20,
                      minDegree: 2,
                      options: [Theme("hub")]),
            ThemeRule(regionClass: .room,
                      options: [Theme("room")]),
            ThemeRule(regionClass: .corridor,
                      options: [Theme("corridor")])
        ]

        let assign = Themer.assignThemes(dungeon: d, graph: g, stats: s, seed: 999, rules: rules)

        // At least one room themed
        let anyRoom = assign.regionToTheme.contains { (rid, th) in
            if case .room = g.nodes[rid]?.kind { return th.name == "hub" || th.name == "room" }
            return false
        }
        #expect(anyRoom, "Expected at least one room to be themed")

        // At least one corridor themed (fallback ensures this)
        let anyCorridor = assign.regionToTheme.contains { (rid, th) in
            if case .corridor = g.nodes[rid]?.kind { return !th.name.isEmpty }
            return false
        }
        #expect(anyCorridor, "Expected at least one corridor to be themed")

        // If the graph actually has dead-end corridor nodes, ensure at least one got "dead_end"
        let deadEndCorridors: Set<RegionID> = Set(
            s.nodes.compactMap { (rid, st) in
                if st.isDeadEnd, case .corridor = g.nodes[rid]?.kind { return rid }
                return nil
            }
        )
        if !deadEndCorridors.isEmpty {
            let themedDeadEnd = assign.regionToTheme.contains { (rid, th) in
                deadEndCorridors.contains(rid) && th.name == "dead_end"
            }
            #expect(themedDeadEnd, "There are dead-end corridors, expected at least one to be themed 'dead_end'")
        }
    }

    @Test("Deterministic theme assignment with same seed")
    func deterministicAssignment() {
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39, algorithm: .bsp(BSPOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: 77
        )
        let g = Regions.extractGraph(d)
        let s = RegionAnalysis.computeStats(dungeon: d, graph: g)

        let rules: [ThemeRule] = [
            ThemeRule(regionClass: .room, options: [Theme("room"), Theme("room_alt")], weights: [3, 1]),
            ThemeRule(regionClass: .corridor, options: [Theme("corridor")])
        ]

        let a1 = Themer.assignThemes(dungeon: d, graph: g, stats: s, seed: 12345, rules: rules)
        let a2 = Themer.assignThemes(dungeon: d, graph: g, stats: s, seed: 12345, rules: rules)
        #expect(a1 == a2)
    }
}
