//
//  RegionIndexEquivalenceTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation
import Testing
@testable import DungeonGrid

@Suite struct RegionIndexEquivalenceTests {

    // First passable tile (deterministic scan)
    private func firstPassable(_ d: Dungeon) -> Point? {
        for y in 0..<d.grid.height {
            for x in 0..<d.grid.width where d.grid[x, y].isPassable {
                return Point(x, y)
            }
        }
        return nil
    }

    // A second passable tile, preferably not equal to `a`
    private func secondPassable(_ d: Dungeon, excluding a: Point) -> Point? {
        for y in 0..<d.grid.height {
            for x in 0..<d.grid.width where d.grid[x, y].isPassable {
                let p = Point(x, y)
                if p != a { return p }
            }
        }
        return nil
    }

    @Test("RegionRouting.routePoints (index) matches direct graph routing")
    func routePointsEquivalence() {
        let cfg = DungeonConfig(width: 61, height: 39, algorithm: .bsp(BSPOptions()),
                                ensureConnected: true, placeDoorsAndTags: true)
        let seed: UInt64 = 101

        let d   = DungeonGrid.generate(config: cfg, seed: seed)
        let idx = DungeonIndex(d)
        let g   = idx.graph

        // Choose endpoints (prefer entrance/exit if present & passable)
        let a: Point = {
            if let s = d.entrance, d.grid[s.x, s.y].isPassable { return s }
            return firstPassable(d) ?? Point(1, 1)
        }()
        let b: Point = {
            if let t = d.exit, d.grid[t.x, t.y].isPassable { return t }
            return secondPassable(d, excluding: a) ?? a
        }()
        if a == b { return }

        // Index-based routing (points → regions internally)
        let rByIndex = RegionRouting.routePoints(d, index: idx, from: a, to: b, doorBias: 0)

        // Graph-based routing (map points → region ids)
        guard
            let rs = Regions.regionID(at: a, labels: idx.labels, width: idx.width),
            let rt = Regions.regionID(at: b, labels: idx.labels, width: idx.width)
        else { return }

        let rByGraph = RegionRouting.route(g, from: rs, to: rt, doorBias: 0)

        #expect((rByIndex == nil) == (rByGraph == nil))
        if let p1 = rByIndex, let p2 = rByGraph {
            #expect(p1.count == p2.count)
            for (u, v) in zip(p1, p2) { #expect(u == v) }
        }
    }

    @Test("LocksPlanner.planAndApply is deterministic with the same inputs")
    func locksDeterminism() {
        let cfg = DungeonConfig(width: 61, height: 39, algorithm: .maze(MazeOptions()),
                                ensureConnected: true, placeDoorsAndTags: true)

        // Two independent copies of the same base (same seed)
        let d1 = DungeonGrid.generate(config: cfg, seed: 55)
        let d2 = DungeonGrid.generate(config: cfg, seed: 55)

        let g1 = DungeonIndex(d1).graph
        let g2 = DungeonIndex(d2).graph

        let (gd1, plan1) = LocksPlanner.planAndApply(d1,
                                                     graph: g1,
                                                     entrance: d1.entrance,
                                                     maxLocks: 2,
                                                     doorBias: 2)
        let (gd2, plan2) = LocksPlanner.planAndApply(d2,
                                                     graph: g2,
                                                     entrance: d2.entrance,
                                                     maxLocks: 2,
                                                     doorBias: 2)

        // Dungeons after lock application should match exactly
        #expect(gd1.grid.tiles == gd2.grid.tiles)
        #expect(gd1.edges.h    == gd2.edges.h)
        #expect(gd1.edges.v    == gd2.edges.v)
        #expect(gd1.entrance   == gd2.entrance)
        #expect(gd1.exit       == gd2.exit)

        // Plans should have the same number of locks
        #expect(plan1.locks.count == plan2.locks.count)
    }
}
