//
//  RegionRoutingAndLocksTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Testing
@testable import DungeonGrid

@Suite struct RegionRoutingAndLocksTests {

    @Test func regionRouteExists() {
        let d = DungeonGrid.generate(config: .init(width: 61, height: 39, algorithm: .bsp(BSPOptions()), ensureConnected: true, placeDoorsAndTags: true), seed: 7)
        let g = Regions.extractGraph(d)
        guard let s = d.entrance, let t = d.exit else { return }
        let route = RegionRouting.routePoints(d, g, from: s, to: t, doorBias: 2)
        #expect(route != nil && !route!.isEmpty)
    }

    @Test func locksAreAppliedAndReturnAPlan() {
        let d = DungeonGrid.generate(config: .init(width: 61, height: 39, algorithm: .uniformRooms(UniformRoomsOptions()), ensureConnected: true, placeDoorsAndTags: true), seed: 11)
        let g = Regions.extractGraph(d)
        let (d2, plan) = LocksPlanner.planAndApply(d, graph: g, entrance: d.entrance, maxLocks: 2, doorBias: 2)
        #expect(plan.locks.count <= 2)

        // Ensure at least one locked edge exists if we planned any locks
        if !plan.locks.isEmpty {
            var foundLocked = false
            // Scan edges for any .locked
            for y in 0..<d2.grid.height {
                for x in 1..<d2.grid.width where d2.edges[vx: x, vy: y] == .locked { foundLocked = true }
            }
            for x in 0..<d2.grid.width {
                for y in 1..<d2.grid.height where d2.edges[hx: x, hy: y] == .locked { foundLocked = true }
            }
            #expect(foundLocked)
        }
    }
}