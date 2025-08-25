//
//  PerfSmokeTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  Non-strict timing harness that prints durations for common paths.
//  These are not thresholded to avoid flakiness; they provide regression visibility.
//


import Foundation
import Testing
@testable import DungeonGrid

@Suite struct PerfSmokeTests {

    private func time(_ label: String, _ body: () -> Void) -> TimeInterval {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        let end = DispatchTime.now().uptimeNanoseconds
        let ms = Double(end - start) / 1_000_000.0
        print(String(format: "[perf] %-28s %8.3f ms", label, ms))
        return ms / 1000.0 // seconds
    }

    @Test("Generate + pipeline (BSP 61x39)")
    func generateBSP() {
        let cfg = DungeonConfig(width: 61, height: 39, algorithm: .bsp(BSPOptions()),
                                ensureConnected: true, placeDoorsAndTags: true)
        let seed: UInt64 = 123

        var dungeon: Dungeon!
        _ = time("BSP base generate") {
            dungeon = DungeonGrid.generate(config: cfg, seed: seed)
        }
        #expect(dungeon != nil && dungeon.grid.width == 61)

        // Index construction timing
        _ = time("DungeonIndex build") {
            _ = DungeonIndex(dungeon)
        }

        // Placement timing
        var pol = PlacementPolicy()
        pol.count = 20
        pol.regionClass = .corridorsOnly
        _ = time("Placer.plan (corridors)") {
            let index = DungeonIndex(dungeon)
            _ = Placer.plan(in: dungeon, index: index, seed: 99, kind: "enemy", policy: pol)
        }
    }

    @Test("Generate + pipeline (Maze 61x39)")
    func generateMaze() {
        let cfg = DungeonConfig(width: 61, height: 39, algorithm: .maze(MazeOptions()),
                                ensureConnected: true, placeDoorsAndTags: true)
        let seed: UInt64 = 321

        _ = time("Maze base generate") {
            _ = DungeonGrid.generate(config: cfg, seed: seed)
        }
    }

    @Test("Generate + pipeline (UniformRooms 61x39)")
    func generateUniform() {
        let cfg = DungeonConfig(width: 61, height: 39, algorithm: .uniformRooms(UniformRoomsOptions()),
                                ensureConnected: true, placeDoorsAndTags: true)
        let seed: UInt64 = 777

        _ = time("UniformRooms base generate") {
            _ = DungeonGrid.generate(config: cfg, seed: seed)
        }
    }

    @Test("Region routing smoke (index vs graph)")
    func routingPerf() {
        let cfg = DungeonConfig(width: 61, height: 39, algorithm: .bsp(BSPOptions()),
                                ensureConnected: true, placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 42)
        let idx = DungeonIndex(d)
        let g = idx.graph

        let a = d.entrance ?? Point(1, 1)
        let b = d.exit     ?? Point(min(d.grid.width-2, a.x+15), a.y)

        _ = time("Routing via index.graph") {
            _ = RegionRouting.route(g, from: Regions.regionID(at: a, labels: idx.labels, width: idx.width)!,
                                       to: Regions.regionID(at: b, labels: idx.labels, width: idx.width)!,
                                       doorBias: 0)
        }
        _ = time("Routing via routePoints(index:)") {
            _ = RegionRouting.routePoints(d, index: idx, from: a, to: b, doorBias: 0)
        }
    }
}
