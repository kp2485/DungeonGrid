//
//  GenerateFullPlacementRequestsTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//

import Testing
@testable import DungeonGrid

@Suite struct GenerateFullPlacementRequestsTests {

    @Test("generateFull(requests:) matches pipeline.placeAll")
    func requestsMatchPipeline() {
        let cfg = DungeonConfig(width: 61, height: 39,
                                algorithm: .bsp(BSPOptions()),
                                ensureConnected: true,
                                placeDoorsAndTags: true)
        let seed: UInt64 = 4242

        var enemy = PlacementPolicy(); enemy.count = 9; enemy.regionClass = .corridorsOnly
        var loot  = PlacementPolicy(); loot.count  = 6; loot.regionClass  = .roomsOnly

        let reqs = [
            PlacementRequest(kind: "enemy",       policy: enemy, seed: 1001),
            PlacementRequest(kind: "loot.health", policy: loot,  seed: 1002),
        ]

        // High-level API
        let full = DungeonGrid.generateFull(config: cfg, seed: seed, requests: reqs)

        // Explicit pipeline on the same base (deterministic with same seed)
        let base = DungeonGrid.generate(config: cfg, seed: seed)
        let viaPipe = DungeonPipeline(base: base)
            .ensureConnected(seed: seed)
            .placeDoors(seed: seed)
            .placeAll(reqs)
            .run()

        // Compare placements per kind (positions)
        let enemies1 = Set((full.placements["enemy"] ?? []).map(\.position))
        let enemies2 = Set((viaPipe.placements["enemy"] ?? []).map(\.position))
        let loot1 = Set((full.placements["loot.health"] ?? []).map(\.position))
        let loot2 = Set((viaPipe.placements["loot.health"] ?? []).map(\.position))

        #expect(enemies1 == enemies2)
        #expect(loot1 == loot2)
    }
}
