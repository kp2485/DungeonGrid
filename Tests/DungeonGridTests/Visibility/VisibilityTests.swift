//
//  VisibilityTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Testing
@testable import DungeonGrid

@Suite struct VisibilityTests {

    @Test("LOS: door blocks when opaque, allows when transparent")
    func doorBlocksOrNot() {
        // Two rooms touching at a single-tile neck; door edges should be created there.
        let R1 = Rect(x: 2, y: 2, width: 10, height: 7)
        let R2 = Rect(x: 12, y: 6, width: 4,  height: 1)

        var g = Grid(width: 24, height: 12, fill: .wall)
        for y in R1.minY...R1.maxY { for x in R1.minX...R1.maxX { g[x, y] = .floor } }
        for y in R2.minY...R2.maxY { for x in R2.minX...R2.maxX { g[x, y] = .floor } }

        let base = Dungeon(
            grid: g,
            rooms: [Room(id: 0, rect: R1), Room(id: 1, rect: R2)],
            seed: 1,
            doors: [],
            entrance: nil,
            exit: nil,
            edges: BuildEdges.fromGrid(g)
        )

        // Long-term API: place door edges (no tagging here).
        let d = EdgeDoors.placeDoors(base)

        let a = Point(R1.midX, R1.midY)
        let b = Point(R2.minX, R2.minY) // a cell in the small right-hand room

        // Doors are OPAQUE: no LOS
        let losOpaque = Visibility.hasLineOfSight(in: d, from: a, to: b, policy: .init(doorTransparent: false))
        if losOpaque {
            TestDebug.print(d)
        }
        #expect(!losOpaque)

        // Doors are TRANSPARENT: LOS exists
        let losTransparent = Visibility.hasLineOfSight(in: d, from: a, to: b, policy: .init(doorTransparent: true))
        if !losTransparent {
            TestDebug.print(d)
        }
        #expect(losTransparent)
    }

    @Test("FOV: returns origin and nearby cells; respects radius")
    func fovRadius() {
        let d = DungeonGrid.generate(
            config: .init(
                width: 41,
                height: 25,
                algorithm: .maze(MazeOptions()),
                ensureConnected: true,
                placeDoorsAndTags: true
            ),
            seed: 7
        )

        // Choose a passable origin:
        // 1) entrance if present and passable,
        // 2) otherwise the passable cell nearest to the map center.
        let origin: Point = {
            if let s = d.entrance, d.grid[s.x, s.y].isPassable { return s }
            let cx = d.grid.width / 2, cy = d.grid.height / 2
            var best: Point? = nil
            var bestDist = Int.max
            for y in 0..<d.grid.height {
                for x in 0..<d.grid.width where d.grid[x, y].isPassable {
                    let dist = abs(x - cx) + abs(y - cy)
                    if dist < bestDist {
                        bestDist = dist
                        best = Point(x, y)
                    }
                }
            }
            return best ?? Point(1, 1)
        }()

        if !d.grid[origin.x, origin.y].isPassable {
            TestDebug.print(d)
        }
        #expect(d.grid[origin.x, origin.y].isPassable)

        let vis5 = Visibility.computeVisible(in: d, from: origin, radius: 5)
        if vis5.isEmpty {
            TestDebug.print(d)
        }
        #expect(!vis5.isEmpty)

        // Farther radius should include all of radius 5 (monotone)
        let vis8 = Visibility.computeVisible(in: d, from: origin, radius: 8)
        let set5: Set<Point> = Set(vis5)
        let set8: Set<Point> = Set(vis8)
        if !set5.isSubset(of: set8) {
            TestDebug.print(d)
        }
        #expect(set5.isSubset(of: set8))
    }
}
