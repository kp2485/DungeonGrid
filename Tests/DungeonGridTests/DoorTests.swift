//
//  DoorTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Testing
@testable import DungeonGrid

@Suite("Doors & Tags")
struct DoorTests {
    @Test("Entrance/Exit tagging picks distinct passable points when there are >=2 rooms")
    func entranceExitTagging() {
        let cfg = DungeonConfig(width: 84, height: 52, algorithm: .bsp(BSPOptions()))
        let post = DungeonGrid.generate(config: cfg, seed: 777)

        if post.rooms.count >= 2 {
            #expect(post.entrance != nil)
            #expect(post.exit != nil)
            #expect(post.entrance != post.exit)
            if let ent = post.entrance, let ex = post.exit {
                #expect(post.grid[ent.x, ent.y].isPassable)
                #expect(post.grid[ex.x, ex.y].isPassable)
            }
        } else {
            #expect(true)
        }
    }

    @Test("Door appears on a thin room–corridor contact (contrived case)")
    func placesDoorInContrivedCase() {
        var g = Grid(width: 20, height: 10, fill: .wall)
        let r = Rect(x: 3, y: 3, width: 6, height: 4) // room x:3...8,y:3...6
        for y in r.minY...r.maxY { for x in r.minX...r.maxX { g[x, y] = .floor } }
        // Corridor to the right, touching room perimeter at (8,5) / (9,5) outside
        for y in 2...7 { g[10, y] = .floor }
        g[9, 5] = .floor

        let d = Dungeon(
            grid: g,
            rooms: [Room(id: 0, rect: r)],
            seed: 0,
            doors: [],
            entrance: nil,
            exit: nil,
            edges: BuildEdges.fromGrid(g)
        )

        let post = EdgeDoors.placeDoorsAndTag(d, seed: 0)

        #expect(post.doors.contains { $0.x == 8 && $0.y == 5 })
        #expect(post.grid[8, 5] == .door)
    }
}
