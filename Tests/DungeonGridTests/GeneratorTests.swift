//
//  GeneratorTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Testing
@testable import DungeonGrid

@Suite("Generator invariants (BSP)")
struct GeneratorTests {
    @Test("Deterministic with same seed")
    func deterministicSameSeed() {
        let cfg = DungeonConfig(width: 64, height: 40, algorithm: .bsp(BSPOptions()))
        let a = DungeonGrid.generate(config: cfg, seed: 12345)
        let b = DungeonGrid.generate(config: cfg, seed: 12345)
        #expect(a.grid.tiles == b.grid.tiles)
        #expect(a.rooms.map(\.rect) == b.rooms.map(\.rect))
    }

    @Test("Rooms are fully carved to floors (pre-doors)")
    func roomsAreFloors() {
        let cfg = DungeonConfig(width: 80, height: 48, algorithm: .bsp(BSPOptions()))
        // disable post-pass so we test raw carving
        var cfgRaw = cfg; cfgRaw.placeDoorsAndTags = false
        let d = DungeonGrid.generate(config: cfgRaw, seed: 7)

        #expect(!d.rooms.isEmpty)
        for room in d.rooms {
            for y in room.rect.minY...room.rect.maxY {
                for x in room.rect.minX...room.rect.maxX {
                    #expect(d.grid[x, y] == .floor, "Non-floor in room at (\(x),\(y))")
                }
            }
        }
    }
}
