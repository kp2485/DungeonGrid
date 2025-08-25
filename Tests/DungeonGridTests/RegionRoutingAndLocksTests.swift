//
//  RegionRoutingAndLocksTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Testing
@testable import DungeonGrid

@Suite struct RegionRoutingAndLocksTests {

    @Test("Graph routing finds a path between entrance and exit")
    func regionRouteExists() {
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39,
                          algorithm: .bsp(BSPOptions()),
                          ensureConnected: true,
                          placeDoorsAndTags: true),
            seed: 7
        )

        let index = DungeonIndex(d)
        let g = index.graph

        guard let a = d.entrance, let b = d.exit else {
            #expect(Bool(false), "Expected entrance/exit to exist")
            return
        }
        guard
            let rs = Regions.regionID(at: a, labels: index.labels, width: index.width),
            let rt = Regions.regionID(at: b, labels: index.labels, width: index.width)
        else {
            #expect(Bool(false), "Entrance/exit not in labeled regions")
            return
        }

        let route = RegionRouting.route(g, from: rs, to: rt, doorBias: 0)
        #expect(route != nil)
    }

    @Test("Locks plan produces locked edges when locks exist")
    func locksPlanProducesLockedEdges() {
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39,
                          algorithm: .uniformRooms(UniformRoomsOptions()),
                          ensureConnected: true,
                          placeDoorsAndTags: true),
            seed: 9
        )

        let g = DungeonIndex(d).graph
        let (d2, plan) = LocksPlanner.planAndApply(d,
                                                   graph: g,
                                                   entrance: d.entrance,
                                                   maxLocks: 2,
                                                   doorBias: 2)

        // Ensure at least one locked edge exists if we planned any locks
        if !plan.locks.isEmpty {
            var foundLocked = false
            // Vertical edges: (vx: x, vy: y), x in 1..<w, y in 0..<h
            for y in 0..<d2.grid.height {
                for x in 1..<d2.grid.width where d2.edges[vx: x, vy: y] == EdgeType.locked {
                    foundLocked = true
                }
            }
            // Horizontal edges: (hx: x, hy: y), y in 1..<h, x in 0..<w
            for x in 0..<d2.grid.width {
                for y in 1..<d2.grid.height where d2.edges[hx: x, hy: y] == EdgeType.locked {
                    foundLocked = true
                }
            }
            #expect(foundLocked)
        }
    }
}
