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
        return ms / 1000.0
    }

    // Helpers: deterministic first/second passable points
    private func firstPassable(_ d: Dungeon) -> Point? {
        for y in 0..<d.grid.height {
            for x in 0..<d.grid.width where d.grid[x, y].isPassable {
                return Point(x, y)
            }
        }
        return nil
    }
    private func secondPassable(_ d: Dungeon, excluding a: Point) -> Point? {
        for y in 0..<d.grid.height {
            for x in 0..<d.grid.width where d.grid[x, y].isPassable {
                let p = Point(x, y)
                if p != a { return p }
            }
        }
        return nil
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

        _ = time("DungeonIndex build") {
            _ = DungeonIndex(dungeon)
        }

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

        // Choose labeled, passable endpoints (prefer entrance/exit)
        let a: Point = {
            if let s = d.entrance, d.grid[s.x, s.y].isPassable { return s }
            return firstPassable(d) ?? Point(1, 1)
        }()
        let b: Point = {
            if let t = d.exit, d.grid[t.x, t.y].isPassable { return t }
            return secondPassable(d, excluding: a) ?? a
        }()
        // If we failed to get two distinct passables, bail out cleanly.
        if a == b { return }

        // Map points → region ids using index labels; guard to avoid force unwrap.
        guard
            let rs = Regions.regionID(at: a, labels: idx.labels, width: idx.width),
            let rt = Regions.regionID(at: b, labels: idx.labels, width: idx.width)
        else { return }

        _ = time("Routing via index.graph") {
            _ = RegionRouting.route(g, from: rs, to: rt, doorBias: 0)
        }
        _ = time("Routing via routePoints(index:)") {
            _ = RegionRouting.routePoints(d, index: idx, from: a, to: b, doorBias: 0)
        }
    }
}
