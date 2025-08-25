//
//  DoorConsistencyTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//

import Testing
@testable import DungeonGrid

@Suite struct DoorConsistencyTests {

    // Helper: does a door-edge touch this tile?
    private func hasAdjacentDoorEdge(_ d: Dungeon, x: Int, y: Int) -> Bool {
        let w = d.grid.width, h = d.grid.height
        // Vertical edges touching (x,y):
        //  - between (x-1,y)↔(x,y)      => vx: x,   vy: y
        //  - between (x,y)↔(x+1,y)      => vx: x+1, vy: y
        if x > 0, d.edges[vx: x,   vy: y] == .door { return true }
        if x + 1 <= w, d.edges[vx: x+1, vy: y] == .door { return true }
        // Horizontal edges touching (x,y):
        //  - between (x,y-1)↔(x,y)      => hx: x, hy: y
        //  - between (x,y)↔(x,y+1)      => hx: x, hy: y+1
        if y > 0, d.edges[hx: x, hy: y] == .door { return true }
        if y + 1 <= h, d.edges[hx: x, hy: y+1] == .door { return true }
        return false
    }

    // Helper: for a given door edge, at least one adjacent tile is marked .door
    private func doorEdgeHasDoorTile(_ d: Dungeon, vertical: Bool, a: Int, b: Int) -> Bool {
        // vertical edge at (vx: a, vy: b) separates (a-1,b) ↔ (a,b)
        // horizontal edge at (hx: a, hy: b) separates (a,b-1) ↔ (a,b)
        let g = d.grid
        if vertical {
            let x = a, y = b
            if x > 0, g[x-1, y] == .door { return true }
            if x < g.width, g[x, y] == .door { return true }
            return false
        } else {
            let x = a, y = b
            if y > 0, g[x, y-1] == .door { return true }
            if y < g.height, g[x, y] == .door { return true }
            return false
        }
    }

    @Test("Every door tile has at least one adjacent door edge")
    func doorTilesHaveEdges() {
        let configs: [DungeonConfig] = [
            .init(width: 41, height: 25, algorithm: .bsp(BSPOptions()), ensureConnected: true, placeDoorsAndTags: true),
            .init(width: 41, height: 25, algorithm: .maze(MazeOptions()), ensureConnected: true, placeDoorsAndTags: true),
            .init(width: 41, height: 25, algorithm: .uniformRooms(UniformRoomsOptions()), ensureConnected: true, placeDoorsAndTags: true),
        ]

        for (i, cfg) in configs.enumerated() {
            let d = DungeonGrid.generate(config: cfg, seed: UInt64(100 + i))
            for p in d.doors {
                #expect(d.grid[p.x, p.y] == .door, "doorTiles must be rasterized as .door in the grid")
                #expect(hasAdjacentDoorEdge(d, x: p.x, y: p.y),
                        "door tile at (\(p.x),\(p.y)) must touch a .door edge")
            }
        }
    }

    @Test("Every door edge has at least one adjacent door tile")
    func doorEdgesHaveTiles() {
        let configs: [DungeonConfig] = [
            .init(width: 41, height: 25, algorithm: .bsp(BSPOptions()), ensureConnected: true, placeDoorsAndTags: true),
            .init(width: 41, height: 25, algorithm: .maze(MazeOptions()), ensureConnected: true, placeDoorsAndTags: true),
            .init(width: 41, height: 25, algorithm: .uniformRooms(UniformRoomsOptions()), ensureConnected: true, placeDoorsAndTags: true),
        ]

        for (i, cfg) in configs.enumerated() {
            let d = DungeonGrid.generate(config: cfg, seed: UInt64(200 + i))
            // Vertical door edges at (vx: x, vy: y) for x in 1...w-1, y in 0...h-1 (0 and w are borders -> .wall)
            for y in 0..<d.grid.height {
                for x in 1..<d.grid.width where d.edges[vx: x, vy: y] == .door {
                    #expect(doorEdgeHasDoorTile(d, vertical: true, a: x, b: y),
                            "vertical door edge at (vx:\(x),vy:\(y)) must have a door tile on either side")
                }
            }
            // Horizontal door edges at (hx: x, hy: y) for y in 1...h-1, x in 0...w-1
            for x in 0..<d.grid.width {
                for y in 1..<d.grid.height where d.edges[hx: x, hy: y] == .door {
                    #expect(doorEdgeHasDoorTile(d, vertical: false, a: x, b: y),
                            "horizontal door edge at (hx:\(x),hy:\(y)) must have a door tile on either side")
                }
            }
        }
    }
}
