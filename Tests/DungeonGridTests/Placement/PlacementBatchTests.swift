//
//  PlacementBatchTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//

import Testing
@testable import DungeonGrid

@Suite struct PlacementBatchTests {

    @Test("Batch placement matches separate calls (deterministic)")
    func batchEqualsSeparate() {
        let cfg = DungeonConfig(width: 61, height: 39, algorithm: .bsp(BSPOptions()),
                                ensureConnected: true, placeDoorsAndTags: true)
        let seed: UInt64 = 42
        let d = DungeonGrid.generate(config: cfg, seed: seed)

        var enemy = PlacementPolicy()
        enemy.count = 10
        enemy.regionClass = .corridorsOnly

        var loot = PlacementPolicy()
        loot.count = 6
        loot.regionClass = .roomsOnly

        let reqs = [
            PlacementRequest(kind: "enemy", policy: enemy, seed: 1001),
            PlacementRequest(kind: "loot.health", policy: loot, seed: 1002),
        ]

        // Separate calls
        let idx = DungeonIndex(d)
        let sepEnemies = Placer.plan(in: d, index: idx, seed: 1001, kind: "enemy", policy: enemy)
        let sepLoot    = Placer.plan(in: d, index: idx, seed: 1002, kind: "loot.health", policy: loot)

        // Batch call
        let batched = Placer.planMany(in: d, index: idx, requests: reqs)

        #expect((batched["enemy"] ?? []).count == sepEnemies.count)
        #expect((batched["loot.health"] ?? []).count == sepLoot.count)

        // Exact positions must match
        let sE = Set((batched["enemy"] ?? []).map(\.position))
        let sL = Set((batched["loot.health"] ?? []).map(\.position))
        #expect(sE == Set(sepEnemies.map(\.position)))
        #expect(sL == Set(sepLoot.map(\.position)))
    }

    @Test("Pipeline placeAll merges into placements by kind")
    func pipelinePlaceAll() {
        let cfg = DungeonConfig(width: 61, height: 39, algorithm: .uniformRooms(UniformRoomsOptions()),
                                ensureConnected: true, placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 77)

        var enemy = PlacementPolicy(); enemy.count = 8; enemy.regionClass = .corridorsOnly
        var loot  = PlacementPolicy(); loot.count  = 5; loot.regionClass  = .roomsOnly

        let res = DungeonPipeline(base: d)
            .placeAll([
                PlacementRequest(kind: "enemy", policy: enemy, seed: 5001),
                PlacementRequest(kind: "loot.health", policy: loot, seed: 5002),
            ])
            .run()

        #expect((res.placements["enemy"] ?? []).count == 8)
        #expect((res.placements["loot.health"] ?? []).count == 5)
    }
}
