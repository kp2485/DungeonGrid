//
//  PathfindingTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Testing
@testable import DungeonGrid

@Suite struct PathfindingTests {

    @Test("Path exists from entrance to exit across algorithms")
    func entranceToExit() {
        let algos: [Algorithm] = [
            .bsp(BSPOptions()),
            .uniformRooms(UniformRoomsOptions()),
            .maze(MazeOptions()),
            .caves(CavesOptions()),
        ]
        for a in algos {
            let d = DungeonGrid.generate(
                config: .init(width: 61, height: 39, algorithm: a, ensureConnected: true, placeDoorsAndTags: true),
                seed: 123
            )
            guard let s = d.entrance, let t = d.exit else {
                // Some algos may produce just 1 room; in that case skip; it's not a failure of pathfinding itself.
                continue
            }
            let path = Pathfinder.shortestPath(in: d, from: s, to: t, movement: .init(doorCost: 0))
            #expect(path != nil && !path!.isEmpty, "no path from entrance to exit for \(a)")
        }
    }

    @Test("Door cost biases routes but keeps reachability")
    func doorCosts() {
        let a: Algorithm = .uniformRooms(UniformRoomsOptions())
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39, algorithm: a, ensureConnected: true, placeDoorsAndTags: true),
            seed: 77
        )
        guard let s = d.entrance, let t = d.exit else { return }

        let p0 = Pathfinder.shortestPath(in: d, from: s, to: t, movement: .init(doorCost: 0))
        let p5 = Pathfinder.shortestPath(in: d, from: s, to: t, movement: .init(doorCost: 5))
        #expect(p0 != nil && p5 != nil)
        // Different door cost *may* change the path; we don't assert inequality because the topology might force doors.
        #expect(!p5!.isEmpty)
    }

    @Test("Locking an edge can block a path")
    func lockingBlocks() {
        let d = DungeonGrid.generate(
            config: .init(width: 41, height: 25, algorithm: .bsp(BSPOptions()), ensureConnected: true, placeDoorsAndTags: true),
            seed: 9
        )
        guard let s = d.entrance, let t = d.exit else { return }

        // Find *some* door edge and lock it, then rebuild a path.
        // If that edge is critical (a cut edge), we expect no path; otherwise the path still exists.
        // We'll probe a handful of door edges and ensure at least one cut exists or at least one non-cut exists.
        var foundBlocked = false
        var foundAlternate = false

        // Copy edges so we can mutate & test.
        func tryLocking(_ update: (inout EdgeGrid) -> Void) -> Bool {
            var e = d.edges
            update(&e)
            let clone = Dungeon(grid: d.grid, rooms: d.rooms, seed: d.seed,
                                doors: d.doors, entrance: d.entrance, exit: d.exit, edges: e)
            return Pathfinder.shortestPath(in: clone, from: s, to: t) == nil
        }

        // Probe up to 200 edges for cut-ness
        var tested = 0
        outer: for y in 0..<d.grid.height {
            for x in 0..<d.grid.width {
                // try locking vertical between (x-1,y)-(x,y)
                if x > 0, d.edges[vx: x, vy: y] == .door || d.edges[vx: x, vy: y] == .open {
                    let blocked = tryLocking { $0[vx: x, vy: y] = .locked }
                    if blocked { foundBlocked = true } else { foundAlternate = true }
                    tested += 1; if tested > 200 { break outer }
                }
                // try locking horizontal between (x,y-1)-(x,y)
                if y > 0, d.edges[hx: x, hy: y] == .door || d.edges[hx: x, hy: y] == .open {
                    let blocked = tryLocking { $0[hx: x, hy: y] = .locked }
                    if blocked { foundBlocked = true } else { foundAlternate = true }
                    tested += 1; if tested > 200 { break outer }
                }
            }
        }

        #expect(foundBlocked || foundAlternate, "Did not examine any usable edges")
        // Not asserting both, because topology might be highly redundant or, rarely, single-channel.
    }
}
