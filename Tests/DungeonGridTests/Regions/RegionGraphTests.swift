//
//  RegionGraphTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Testing
@testable import DungeonGrid

@Suite struct RegionGraphTests {

    @Test("Graph has room nodes and at least one corridor; edges connect distinct regions")
    func basicGraph() {
        let cfg = DungeonConfig(width: 61, height: 39,
                                algorithm: .uniformRooms(UniformRoomsOptions()),
                                ensureConnected: true, placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 123)
        let g = Regions.extractGraph(d)

        // There should be a node per room
        let roomNodeCount = g.nodes.values.filter {
            if case .room = $0.kind { return true } else { return false }
        }.count
        #expect(roomNodeCount == d.rooms.count)

        // There should be at least one corridor component on typical maps
        let corridorNodeCount = g.nodes.values.filter {
            if case .corridor = $0.kind { return true } else { return false }
        }.count
        #expect(corridorNodeCount >= 1)

        // Edges connect different regions and have positive counts
        for e in g.edges {
            #expect(e.a != e.b)
            #expect(e.openCount + e.doorCount > 0)
        }
    }

    @Test("Room↔room one-tile neck becomes a door edge in the region graph")
    func roomToRoomDoorShowsUp() {
        // Big room (x:2...11, y:2...8)
        let R1 = Rect(x: 2, y: 2, width: 10, height: 7)
        // Small room touching at a single row y=6 (x:12...15, y:6...6)
        let R2 = Rect(x: 12, y: 6, width: 4, height: 1)

        var grid = Grid(width: 24, height: 12, fill: .wall)
        for y in R1.minY...R1.maxY { for x in R1.minX...R1.maxX { grid[x,y] = .floor } }
        for y in R2.minY...R2.maxY { for x in R2.minX...R2.maxX { grid[x,y] = .floor } }

        // Build, then place edge-doors (default policy: span 1)
        let base = Dungeon(grid: grid,
                           rooms: [Room(id: 0, rect: R1), Room(id: 1, rect: R2)],
                           seed: 1, doors: [], entrance: nil, exit: nil,
                           edges: BuildEdges.fromGrid(grid))
        let d = EdgeDoors.placeDoorsAndTag(base, seed: 1)

        let g = Regions.extractGraph(d)

        // Find the region ids for the two rooms
        guard let n0 = g.nodes.first(where: { if case .room(0) = $0.value.kind { return true } else { return false } })?.key,
              let n1 = g.nodes.first(where: { if case .room(1) = $0.value.kind { return true } else { return false } })?.key
        else { #expect(Bool(false), "Missing room nodes"); return }

        // Expect at least one door edge between these two rooms
        let doorEdge = g.edges.first(where: { (e) in
            (e.a == n0 && e.b == n1) || (e.a == n1 && e.b == n0)
        })
        #expect(doorEdge != nil && doorEdge!.doorCount > 0,
                "Expected a room↔room door edge in the region graph")
    }
}
