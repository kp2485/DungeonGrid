//
//  ConnectivityTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Testing
@testable import DungeonGrid

@Suite("Connectivity")
struct ConnectivityTests {
    @Test("ensureConnected produces a single connected component and is idempotent")
    func ensureConnectedWorksAndIsIdempotent() {
        var cfg = DungeonConfig(width: 80, height: 48, algorithm: .bsp(BSPOptions()))
        cfg.placeDoorsAndTags = false

        for seed: UInt64 in [1, 2, 3, 10, 42, 77] {
            let raw = DungeonGrid.generate(config: cfg, seed: seed)
            let fixed = Connectivity.ensureConnected(raw, seed: seed)
            let after = Connectivity.report(for: fixed)
            #expect(after.componentCount == 1)

            let fixed2 = Connectivity.ensureConnected(fixed, seed: seed)
            let after2 = Connectivity.report(for: fixed2)
            #expect(after2.componentCount == 1)
            #expect(after2.floorCount == after.floorCount)
        }
    }

    @Test("Artificial two-island dungeon gets connected")
    func artificialIslandsConnect() {
        var g = Grid(width: 30, height: 12, fill: .wall)
        func carve(_ r: Rect) {
            for y in r.minY...r.maxY { for x in r.minX...r.maxX { g[x, y] = .floor } }
        }
        let r1 = Rect(x: 2, y: 3, width: 6, height: 5)
        let r2 = Rect(x: 20, y: 4, width: 6, height: 5)
        carve(r1); carve(r2)

        let d = Dungeon(
            grid: g,
            rooms: [Room(id: 0, rect: r1), Room(id: 1, rect: r2)],
            seed: 999,
            doors: [],
            entrance: nil,
            exit: nil,
            edges: BuildEdges.fromGrid(g)   // ← add this
        )

        let fixed = Connectivity.ensureConnected(d, seed: 123)
        let after = Connectivity.report(for: fixed)
        #expect(after.componentCount == 1)
        #expect(after.floorCount >= 2 * (6*5))
    }
}
