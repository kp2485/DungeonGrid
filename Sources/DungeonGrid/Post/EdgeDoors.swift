//
//  EdgeDoors.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

/// Policy for converting narrow region contacts into edge-doors and how to rasterize them.
public struct DoorPolicy: Sendable, Equatable {
    /// Max contiguous boundary length (in tiles) to treat as a "door" for ROOM–ROOM contacts.
    /// 1 = classic single-tile doorway between rooms (recommended).
    public var maxSpanRoomRoom: Int = 1

    /// Max contiguous boundary length to treat as a "door" for ROOM–CORRIDOR contacts.
    /// Keep small to avoid huge doorway strips; 1 is typical.
    public var maxSpanRoomCorridor: Int = 1

    /// Rasterization: for room–room doors, mark both room cells as `.door`.
    public var rasterizeRoomRoomBothSides: Bool = true

    /// Rasterization: for room–corridor doors, mark only the room-side cell as `.door`.
    public var rasterizeRoomCorridorRoomSideOnly: Bool = true

    public init() {}
}

/// Builds door edges between regions and optional rasterized door tiles.
/// Source of truth is `EdgeGrid` (edges), not tiles.
public enum EdgeDoors {

    /// Convert narrow region boundary segments into `.door` edges, rasterize door tiles for compatibility,
    /// and tag entrance/exit (farthest room centers by edge-aware BFS).
    @discardableResult
    public static func placeDoorsAndTag(_ d: Dungeon,
                                        seed: UInt64,
                                        policy: DoorPolicy = .init()) -> Dungeon {
        let w = d.grid.width, h = d.grid.height
        @inline(__always) func idx(_ x:Int,_ y:Int)->Int { y*w + x }

        // 1) Derive a fresh edge layer from the current grid (open iff both sides passable).
        //    This ensures we reflect any earlier carving/connection steps.
        var edges = BuildEdges.fromGrid(d.grid)

        // 2) Build room ID map: -1 = corridor; >=0 = that room's id
        var roomID = Array(repeating: -1, count: w*h)
        for room in d.rooms {
            for y in room.minY...room.maxY {
                for x in room.minX...room.maxX where d.grid[x,y].isPassable {
                    roomID[idx(x,y)] = room.id
                }
            }
        }

        // Helper: unordered pair equality (for ROOM–ROOM segment continuity).
        @inline(__always)
        func samePair(_ a:Int,_ b:Int,_ c:Int,_ d:Int) -> Bool {
            (a == c && b == d) || (a == d && b == c)
        }

        // 3) Scan vertical boundaries (between (x-1,y) and (x,y)); group into segments; classify RR/RC → door if span ≤ threshold.
        for y in 0..<h {
            var x = 1
            while x < w {
                let lPass = d.grid[x-1, y].isPassable
                let rPass = d.grid[x,   y].isPassable
                if !(lPass && rPass) { x += 1; continue }

                let lID = roomID[idx(x-1,y)]   // -1 corridor
                let rID = roomID[idx(x,  y)]
                let isRR = (lID >= 0 && rID >= 0 && lID != rID)  // room A ↔ room B
                let isRC = (lID >= 0) != (rID >= 0)              // room ↔ corridor
                if !(isRR || isRC) { x += 1; continue }         // corridor↔corridor or same room

                // Grow contiguous segment along Y that preserves the same relationship (and room pair for RR).
                let pairA = lID, pairB = rID
                let segX = x
                var y0 = y, y1 = y
                while y1 + 1 < h {
                    let lP = d.grid[segX-1, y1+1].isPassable
                    let rP = d.grid[segX,   y1+1].isPassable
                    if !(lP && rP) { break }
                    let l2 = roomID[idx(segX-1, y1+1)], r2 = roomID[idx(segX, y1+1)]
                    let rr2 = (l2 >= 0 && r2 >= 0 && l2 != r2)
                    let rc2 = (l2 >= 0) != (r2 >= 0)
                    if isRR && rr2 && samePair(pairA, pairB, l2, r2) { y1 += 1; continue }
                    if isRC && rc2 { y1 += 1; continue }
                    break
                }

                let span = y1 - y0 + 1
                let maxSpan = isRR ? policy.maxSpanRoomRoom : policy.maxSpanRoomCorridor
                if span <= maxSpan {
                    for yy in y0...y1 { edges[vx: segX, vy: yy] = .door }
                }
                x = segX + 1
            }
        }

        // 4) Scan horizontal boundaries (between (x,y-1) and (x,y)).
        for x in 0..<w {
            var y = 1
            while y < h {
                let tPass = d.grid[x, y-1].isPassable
                let bPass = d.grid[x, y  ].isPassable
                if !(tPass && bPass) { y += 1; continue }

                let tID = roomID[idx(x, y-1)]
                let bID = roomID[idx(x, y  )]
                let isRR = (tID >= 0 && bID >= 0 && tID != bID)
                let isRC = (tID >= 0) != (bID >= 0)
                if !(isRR || isRC) { y += 1; continue }

                let pairA = tID, pairB = bID
                let segY = y
                var x0 = x, x1 = x
                while x1 + 1 < w {
                    let tP = d.grid[x1+1, segY-1].isPassable
                    let bP = d.grid[x1+1, segY  ].isPassable
                    if !(tP && bP) { break }
                    let t2 = roomID[idx(x1+1, segY-1)], b2 = roomID[idx(x1+1, segY)]
                    let rr2 = (t2 >= 0 && b2 >= 0 && t2 != b2)
                    let rc2 = (t2 >= 0) != (b2 >= 0)
                    if isRR && rr2 && samePair(pairA, pairB, t2, b2) { x1 += 1; continue }
                    if isRC && rc2 { x1 += 1; continue }
                    break
                }

                let span = x1 - x0 + 1
                let maxSpan = isRR ? policy.maxSpanRoomRoom : policy.maxSpanRoomCorridor
                if span <= maxSpan {
                    for xx in x0...x1 { edges[hx: xx, hy: segY] = .door }
                }
                y = segY + 1
            }
        }

        // 5) Rasterize door tiles for compatibility (mark the correct side(s))
        var grid = d.grid
        var doorTiles: [Point] = []

        // Vertical door edges at (vx: x, vy: y) separate (x-1,y) ↔ (x,y)
        for y in 0..<h {
            for x in 1..<w where edges[vx: x, vy: y] == .door {
                let li = idx(x-1,y), ri = idx(x,y)
                let lIsRoom = roomID[li] >= 0
                let rIsRoom = roomID[ri] >= 0
                if lIsRoom && rIsRoom {
                    if policy.rasterizeRoomRoomBothSides {
                        grid[x-1, y] = .door; doorTiles.append(Point(x-1, y))
                        grid[x,   y] = .door; doorTiles.append(Point(x,   y))
                    } else {
                        grid[x-1, y] = .door; doorTiles.append(Point(x-1, y))
                    }
                } else if lIsRoom != rIsRoom {
                    if policy.rasterizeRoomCorridorRoomSideOnly {
                        let (rx, ry) = lIsRoom ? (x-1, y) : (x, y)
                        grid[rx, ry] = .door; doorTiles.append(Point(rx, ry))
                    } else {
                        // both sides (rare preference)
                        grid[x-1, y] = .door; doorTiles.append(Point(x-1, y))
                        grid[x,   y] = .door; doorTiles.append(Point(x,   y))
                    }
                }
            }
        }
        // Horizontal door edges at (hx: x, hy: y) separate (x,y-1) ↔ (x,y)
        for x in 0..<w {
            for y in 1..<h where edges[hx: x, hy: y] == .door {
                let ti = idx(x,y-1), bi = idx(x,y)
                let tIsRoom = roomID[ti] >= 0
                let bIsRoom = roomID[bi] >= 0
                if tIsRoom && bIsRoom {
                    if policy.rasterizeRoomRoomBothSides {
                        grid[x, y-1] = .door; doorTiles.append(Point(x, y-1))
                        grid[x, y  ] = .door; doorTiles.append(Point(x, y  ))
                    } else {
                        grid[x, y-1] = .door; doorTiles.append(Point(x, y-1))
                    }
                } else if tIsRoom != bIsRoom {
                    if policy.rasterizeRoomCorridorRoomSideOnly {
                        let (rx, ry) = tIsRoom ? (x, y-1) : (x, y)
                        grid[rx, ry] = .door; doorTiles.append(Point(rx, ry))
                    } else {
                        grid[x, y-1] = .door; doorTiles.append(Point(x, y-1))
                        grid[x, y  ] = .door; doorTiles.append(Point(x, y  ))
                    }
                }
            }
        }
        doorTiles = Array(Set(doorTiles)) // dedup

        // 6) Entrance/Exit tagging: farthest pair of room centers (edge-aware BFS distance)
        let centers: [Point] = d.rooms.map { Point($0.rect.midX, $0.rect.midY) }
        var entrance: Point? = centers.first
        var exit: Point? = nil
        if centers.count >= 2 {
            var best = -1, bestPair = (0, 1)
            for i in 0..<centers.count {
                let dmap = edgeBFS(from: centers[i], grid: grid, edges: edges)
                for j in (i+1)..<centers.count {
                    let idxj = centers[j].y * w + centers[j].x
                    let dist = dmap[idxj] >= 0
                        ? dmap[idxj]
                        : abs(centers[i].x - centers[j].x) + abs(centers[i].y - centers[j].y)
                    if dist > best { best = dist; bestPair = (i, j) }
                }
            }
            entrance = centers[bestPair.0]; exit = centers[bestPair.1]
        }

        return Dungeon(
            grid: grid,
            rooms: d.rooms,
            seed: d.seed,
            doors: doorTiles,
            entrance: entrance,
            exit: exit,
            edges: edges
        )
    }
}

// MARK: - Edge-aware BFS (used for entrance/exit tagging)

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
