//
//  EdgeDoors.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public struct DoorPolicy: Sendable {
    public var maxSpanRoomRoom: Int = 1
    public var maxSpanRoomCorridor: Int = 1
    public var rasterizeRoomRoomBothSides: Bool = true
    public var rasterizeRoomCorridorRoomSideOnly: Bool = true
    public init() {}
}

public enum EdgeDoors {
    /// Build edges (if none), convert narrow contacts to doors on edges,
    /// and optionally rasterize `.door` tiles for compatibility.
    public static func placeDoorsAndTag(_ d: Dungeon, seed: UInt64, policy: DoorPolicy = .init()) -> Dungeon {
        // 1) Ensure we have an edge layer
        var edges = d.edges
        if edges.width == 0 || edges.height == 0 {
            edges = BuildEdges.fromGrid(d.grid)
        }

        // 2) Room membership bitmap for passable cells
        let w = d.grid.width, h = d.grid.height
        var isRoom = Array(repeating: false, count: w*h)
        for room in d.rooms {
            for y in room.minY...room.maxY {
                for x in room.minX...room.maxX where d.grid[x,y].isPassable {
                    isRoom[y*w + x] = true
                }
            }
        }

        // 3) Group boundary edges into segments and classify (ROOM–ROOM vs ROOM–CORRIDOR)
        // Vertical boundaries (between (x-1,y) and (x,y)): x in 1...w-1
        for y in 0..<h {
            var x = 1
            while x < w {
                // start of potential boundary?
                let leftOK  = d.grid[x-1, y].isPassable
                let rightOK = d.grid[x,   y].isPassable
                if !(leftOK && rightOK) { x += 1; continue }
                let leftRoom  = isRoom[y*w + (x-1)]
                let rightRoom = isRoom[y*w + x]
                if leftRoom == rightRoom { x += 1; continue }

                // walk contiguous vertical segment at this x
                let segX = x
                var y0 = y
                var y1 = y
                while y1+1 < h,
                      d.grid[segX-1, y1+1].isPassable,
                      d.grid[segX,   y1+1].isPassable,
                      isRoom[(y1+1)*w + (segX-1)] != isRoom[(y1+1)*w + segX] {
                    y1 += 1
                }
                let span = y1 - y0 + 1
                let isRR = leftRoom && rightRoom
                let maxSpan = isRR ? policy.maxSpanRoomRoom : policy.maxSpanRoomCorridor
                let makeDoor = span <= maxSpan

                if makeDoor {
                    for yy in y0...y1 {
                        edges[vx: segX, vy: yy] = .door
                    }
                }
                x = segX + 1
            }
        }

        // Horizontal boundaries (between (x,y-1) and (x,y)): y in 1...h-1
        for x in 0..<w {
            var y = 1
            while y < h {
                let topOK = d.grid[x, y-1].isPassable
                let botOK = d.grid[x, y].isPassable
                if !(topOK && botOK) { y += 1; continue }
                let topRoom = isRoom[(y-1)*w + x]
                let botRoom = isRoom[y*w + x]
                if topRoom == botRoom { y += 1; continue }

                // walk contiguous horizontal segment at this y
                let segY = y
                var x0 = x
                var x1 = x
                while x1+1 < w,
                      d.grid[x1+1, segY-1].isPassable,
                      d.grid[x1+1, segY].isPassable,
                      isRoom[(segY-1)*w + (x1+1)] != isRoom[segY*w + (x1+1)] {
                    x1 += 1
                }
                let span = x1 - x0 + 1
                let isRR = topRoom && botRoom
                let maxSpan = isRR ? policy.maxSpanRoomRoom : policy.maxSpanRoomCorridor
                let makeDoor = span <= maxSpan

                if makeDoor {
                    for xx in x0...x1 {
                        edges[hx: xx, hy: segY] = .door
                    }
                }
                y = segY + 1
            }
        }

        // 4) Optional: rasterize door tiles for compatibility
        var grid = d.grid
        var doorTiles: [Point] = []

        if policy.rasterizeRoomCorridorRoomSideOnly || policy.rasterizeRoomRoomBothSides {
            // For each cell, if any of its incident edges is a door, mark that cell as .door
            // (room–corridor: mark the room side only; room–room: mark both)
            for y in 0..<h {
                for x in 0..<w where grid[x,y].isPassable {
                    var incidentDoor = false
                    // vertical edges around (x,y): vx x and x+1
                    if x > 0, edges[vx: x, vy: y] == .door { incidentDoor = true }
                    if x + 1 <= w-1, edges[vx: x+1, vy: y] == .door { incidentDoor = true }
                    // horizontal edges: hy y and y+1
                    if y > 0, edges[hx: x, hy: y] == .door { incidentDoor = true }
                    if y + 1 <= h-1, edges[hx: x, hy: y+1] == .door { incidentDoor = true }

                    if incidentDoor {
                        // decide whether to rasterize based on room/corridor policy
                        let room = isRoom[y*w + x]
                        if room {
                            grid[x,y] = .door
                            doorTiles.append(Point(x,y))
                        } else if policy.rasterizeRoomRoomBothSides == true {
                            // For pure corridor cells in room–room doors we typically don't mark,
                            // but room–room doors have no corridor side; this branch rarely triggers.
                        }
                    }
                }
            }
        }

        // 5) Entrance/exit (unchanged; BFS will use edges for correctness)
        let (entrance, exit) = tagEntranceExit(rooms: d.rooms, grid: grid, edges: edges)

        return Dungeon(grid: grid,
                       rooms: d.rooms,
                       seed: d.seed,
                       doors: Array(Set(doorTiles)),
                       entrance: entrance,
                       exit: exit,
                       edges: edges)
    }
}

// Pick farthest room centers (by edge-aware BFS)
fileprivate func tagEntranceExit(rooms: [Room], grid: Grid, edges: EdgeGrid) -> (Point?, Point?) {
    let centers = rooms.map { Point($0.rect.midX, $0.rect.midY) }
    guard centers.count >= 2 else { return (centers.first, nil) }
    var best = -1, pair = (0, 1)
    for i in 0..<centers.count {
        let dmap = edgeBFS(from: centers[i], grid: grid, edges: edges)
        for j in (i+1)..<centers.count {
            let idx = centers[j].y * grid.width + centers[j].x
            let d = dmap[idx]
            let val = d >= 0 ? d : abs(centers[i].x - centers[j].x) + abs(centers[i].y - centers[j].y)
            if val > best { best = val; pair = (i, j) }
        }
    }
    return (centers[pair.0], centers[pair.1])
}

// Edge-aware BFS
fileprivate func edgeBFS(from start: Point, grid: Grid, edges: EdgeGrid) -> [Int] {
    let w = grid.width, h = grid.height, total = w*h
    var dist = Array(repeating: -1, count: total)
    guard grid[start.x, start.y].isPassable else { return dist }
    var q = [start.y*w + start.x]; dist[q[0]] = 0

    while !q.isEmpty {
        let cur = q.removeFirst()
        let x = cur % w, y = cur / w, base = dist[cur]

        // 4-neighbors with edge check
        if x > 0, grid[x-1, y].isPassable, edges.canStep(from: x, y, to: x-1, y) {
            let ni = y*w + (x-1); if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
        }
        if x + 1 < w, grid[x+1, y].isPassable, edges.canStep(from: x, y, to: x+1, y) {
            let ni = y*w + (x+1); if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
        }
        if y > 0, grid[x, y-1].isPassable, edges.canStep(from: x, y, to: x, y-1) {
            let ni = (y-1)*w + x; if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
        }
        if y + 1 < h, grid[x, y+1].isPassable, edges.canStep(from: x, y, to: x, y+1) {
            let ni = (y+1)*w + x; if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
        }
    }
    return dist
}
