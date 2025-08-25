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

    @Test("RegionRouting.routePoints matches between index and direct graph")
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

        // If we failed to get two distinct passables, just bail out cleanly.
        if a == b { return }

        // Index-based routing
        let rByIndex = RegionRouting.routePoints(d, index: idx, from: a, to: b, doorBias: 0)

        // Graph-based routing (map points → region ids via index labels)
        let labels = idx.labels
        let w      = idx.width
        guard
            let rs = Regions.regionID(at: a, labels: labels, width: w),
            let rt = Regions.regionID(at: b, labels: labels, width: w)
        else {
            return
        }
        let rByGraph = RegionRouting.route(g, from: rs, to: rt, doorBias: 0)

        // Either both nil or equal sequences.
        #expect((rByIndex == nil) == (rByGraph == nil))
        if let p1 = rByIndex, let p2 = rByGraph {
            #expect(p1.count == p2.count)
            for (u, v) in zip(p1, p2) { #expect(u == v) }
        }
    }

    @Test("LocksPlanner.planAndApply matches between index and direct graph")
    func locksEquivalence() {
        let cfg = DungeonConfig(width: 61, height: 39, algorithm: .maze(MazeOptions()),
                                ensureConnected: true, placeDoorsAndTags: true)

        let d1 = DungeonGrid.generate(config: cfg, seed: 55)
        let d2 = DungeonGrid.generate(config: cfg, seed: 55)

        let idx1 = DungeonIndex(d1)

        // Graph-based
        let (gdGraph, planGraph) = LocksPlanner.planAndApply(d1,
                                                             graph: idx1.graph,
                                                             entrance: d1.entrance,
                                                             maxLocks: 2,
                                                             doorBias: 2)

        // Index-based
        let (gdIndex, planIndex) = LocksPlanner.planAndApply(d2,
                                                             index: DungeonIndex(d2),
                                                             maxLocks: 2,
                                                             doorBias: 2)

        #expect(gdGraph.grid.tiles == gdIndex.grid.tiles)
        #expect(gdGraph.edges.h     == gdIndex.edges.h)
        #expect(gdGraph.edges.v     == gdIndex.edges.v)
        #expect(gdGraph.rooms.count == gdIndex.rooms.count)
        #expect(gdGraph.entrance    == gdIndex.entrance)
        #expect(gdGraph.exit        == gdIndex.exit)

        #expect(planGraph.locks.count == planIndex.locks.count)
    }
}
