//
//  DoorTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Testing
@testable import DungeonGrid

@Suite struct DoorTests {

    @Test("Entrance/Exit tagging exists and is sane (when enabled)")
    func entranceExitTagging() {
        // Synthetic: two rooms with a seam should produce a door and tag S/E.
        let R1 = Rect(x: 2, y: 2, width: 10, height: 7)
        let R2 = Rect(x: 12, y: 6, width: 4,  height: 1)

        var g = Grid(width: 24, height: 12, fill: .wall)
        for y in R1.minY...R1.maxY { for x in R1.minX...R1.maxX { g[x,y] = .floor } }
        for y in R2.minY...R2.maxY { for x in R2.minX...R2.maxX { g[x,y] = .floor } }

        let base = Dungeon(grid: g,
                           rooms: [Room(id: 0, rect: R1), Room(id: 1, rect: R2)],
                           seed: 1, doors: [], entrance: nil, exit: nil,
                           edges: BuildEdges.fromGrid(g))

        let post = EdgeDoors.placeDoorsAndTag(base, seed: 1)

        #expect(post.entrance != nil, "Expected entrance to be tagged")
        #expect(post.exit != nil, "Expected exit to be tagged")
        if let s = post.entrance, let e = post.exit {
            #expect(s != e, "Entrance equals exit (should differ)")
            #expect(post.grid[s.x, s.y].isPassable, "Entrance not on passable tile")
            #expect(post.grid[e.x, e.y].isPassable, "Exit not on passable tile")
        }
    }

    @Test("Edges-as-truth: every door tile touches a door edge and vice versa (across seeds)")
    func doorEdgesConsistency() {
        for worldSeed in TestEnv.fuzzSeeds {
            let cfg = DungeonConfig(width: 41, height: 25,
                                    algorithm: .bsp(BSPOptions()),
                                    ensureConnected: true,
                                    placeDoorsAndTags: true)
            let d = DungeonGrid.generate(config: cfg, seed: worldSeed)

            // Check if a door tile touches at least one door edge.
            // Note: Edge indices are valid for vx in 1..<w and hx in 1..<h — avoid <= w / <= h.
            func touchesDoorEdge(_ x: Int, _ y: Int) -> Bool {
                let w = d.grid.width, h = d.grid.height
                // Vertical neighbors: edges between (x-1,y)↔(x,y) and (x,y)↔(x+1,y)
                if x > 0, d.edges[vx: x, vy: y] == .door { return true }
                if x + 1 < w, d.edges[vx: x + 1, vy: y] == .door { return true }
                // Horizontal neighbors: edges between (x,y-1)↔(x,y) and (x,y)↔(x,y+1)
                if y > 0, d.edges[hx: x, hy: y] == .door { return true }
                if y + 1 < h, d.edges[hx: x, hy: y + 1] == .door { return true }
                return false
            }

            for p in d.doors {
                #expect(touchesDoorEdge(p.x, p.y),
                        "Door tile at (\(p.x),\(p.y)) does not touch a .door edge (seed \(worldSeed))")
            }

            // For each door edge, ensure at least one adjacent tile is a .door tile.
            func edgeHasDoorTile(vertical: Bool, a: Int, b: Int) -> Bool {
                let g = d.grid
                if vertical {
                    let x = a, y = b
                    if x > 0, g[x - 1, y] == .door { return true }
                    if x < g.width, g[x, y] == .door { return true }
                } else {
                    let x = a, y = b
                    if y > 0, g[x, y - 1] == .door { return true }
                    if y < g.height, g[x, y] == .door { return true }
                }
                return false
            }

            // Vertical edges: (vx: x, vy: y) with x in 1..<w
            for y in 0..<d.grid.height {
                for x in 1..<d.grid.width where d.edges[vx: x, vy: y] == .door {
                    #expect(edgeHasDoorTile(vertical: true, a: x, b: y),
                            "Vertical door edge (vx:\(x),vy:\(y)) has no adjacent door tile (seed \(worldSeed))")
                }
            }
            // Horizontal edges: (hx: x, hy: y) with y in 1..<h
            for x in 0..<d.grid.width {
                for y in 1..<d.grid.height where d.edges[hx: x, hy: y] == .door {
                    #expect(edgeHasDoorTile(vertical: false, a: x, b: y),
                            "Horizontal door edge (hx:\(x),hy:\(y)) has no adjacent door tile (seed \(worldSeed))")
                }
            }
        }
    }
}
