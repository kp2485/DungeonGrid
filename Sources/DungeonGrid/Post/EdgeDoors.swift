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

    /// Doors only (no entrance/exit tagging).
    /// - Returns: new `Dungeon` with updated `edges`, `grid` door tiles, and `doors` list.
    @discardableResult
    public static func placeDoors(_ d: Dungeon,
                                  policy: DoorPolicy = .init()) -> Dungeon {
        let (edges, newGrid, doorTiles) = buildEdgesAndRasterize(from: d, policy: policy)
        return Dungeon(
            grid: newGrid,
            rooms: d.rooms,
            seed: d.seed,
            doors: doorTiles,
            entrance: d.entrance,
            exit: d.exit,
            edges: edges
        )
    }

    /// Convert narrow region boundary segments into `.door` edges, rasterize door tiles, and tag entrance/exit.
    /// Entrance/exit are chosen as the farthest pair of room centers by edge-aware BFS distance.
    @discardableResult
    public static func placeDoorsAndTag(_ d: Dungeon,
                                        seed: UInt64,
                                        policy: DoorPolicy = .init()) -> Dungeon {
        let (edges, newGrid, doorTiles) = buildEdgesAndRasterize(from: d, policy: policy)

        // Entrance/Exit tagging: farthest pair of room centers by edge-aware BFS.
        let w = newGrid.width
        let centers: [Point] = d.rooms.map { Point($0.rect.midX, $0.rect.midY) }

        var entrance: Point? = d.entrance
        var exit: Point? = d.exit
        if centers.count >= 2 {
            var best = -1
            var bestPair = (0, 1)
            for i in 0..<centers.count {
                let distMap = edgeBFS(from: centers[i], grid: newGrid, edges: edges)
                for j in (i+1)..<centers.count {
                    let idxj = centers[j].y * w + centers[j].x
                    let dist = distMap[idxj]
                    if dist > best {
                        best = dist
                        bestPair = (i, j)
                    }
                }
            }
            // If BFS couldn’t reach (dist == -1), fall back to Manhattan
            if best < 0 {
                var bestMan = -1
                var manPair = (0, 1)
                for i in 0..<centers.count {
                    for j in (i+1)..<centers.count {
                        let m = abs(centers[i].x - centers[j].x) + abs(centers[i].y - centers[j].y)
                        if m > bestMan {
                            bestMan = m; manPair = (i, j)
                        }
                    }
                }
                entrance = centers[manPair.0]
                exit = centers[manPair.1]
            } else {
                entrance = centers[bestPair.0]
                exit = centers[bestPair.1]
            }
        }

        return Dungeon(
            grid: newGrid,
            rooms: d.rooms,
            seed: d.seed,
            doors: doorTiles,
            entrance: entrance,
            exit: exit,
            edges: edges
        )
    }
}

// MARK: - Core: build door edges + rasterize tiles

private extension EdgeDoors {
    /// Returns (edges, newGridWithDoorTiles, doorTiles)
    static func buildEdgesAndRasterize(from d: Dungeon,
                                       policy: DoorPolicy) -> (EdgeGrid, Grid, [Point]) {
        let w = d.grid.width, h = d.grid.height
        @inline(__always) func idx(_ x:Int,_ y:Int)->Int { y*w + x }

        // 1) Derive base edges from grid
        var edges = BuildEdges.fromGrid(d.grid)

        // 2) Build room ID map: -1 = corridor; >=0 = that room's id
        var roomID = Array(repeating: -1, count: w*h)
        for room in d.rooms {
            for y in room.minY...room.maxY {
                for x in room.minX...room.maxX where d.grid[x, y].isPassable {
                    roomID[idx(x, y)] = room.id
                }
            }
        }

        // Helper: unordered pair equality
        @inline(__always)
        func samePair(_ a:Int,_ b:Int,_ c:Int,_ d:Int) -> Bool {
            (a == c && b == d) || (a == d && b == c)
        }

        // 3) Mark vertical door edges where appropriate (between (x-1,y) and (x,y))
        // We treat each column seam independently and grow segments along Y.
        for x in 1..<w {
            var y = 0
            while y < h {
                let lPass = d.grid[x-1, y].isPassable
                let rPass = d.grid[x,   y].isPassable
                if !(lPass && rPass) { y += 1; continue }

                let lID = roomID[idx(x-1, y)]
                let rID = roomID[idx(x,   y)]
                let isRR = (lID >= 0 && rID >= 0 && lID != rID)
                let isRC = (lID >= 0) != (rID >= 0)
                if !(isRR || isRC) { y += 1; continue }

                let pairA = lID, pairB = rID
                let y0 = y
                var y1 = y
                while y1 + 1 < h {
                    let lP = d.grid[x-1, y1+1].isPassable
                    let rP = d.grid[x,   y1+1].isPassable
                    if !(lP && rP) { break }
                    let l2 = roomID[idx(x-1, y1+1)], r2 = roomID[idx(x, y1+1)]
                    let rr2 = (l2 >= 0 && r2 >= 0 && l2 != r2)
                    let rc2 = (l2 >= 0) != (r2 >= 0)
                    if isRR && rr2 && samePair(pairA, pairB, l2, r2) { y1 += 1; continue }
                    if isRC && rc2 { y1 += 1; continue }
                    break
                }

                let span = y1 - y0 + 1
                let maxSpan = isRR ? policy.maxSpanRoomRoom : policy.maxSpanRoomCorridor
                if span <= maxSpan {
                    for yy in y0...y1 { edges[vx: x, vy: yy] = .door }
                }
                y = y1 + 1
            }
        }

        // 4) Mark horizontal door edges where appropriate (between (x,y-1) and (x,y))
        for y in 1..<h {
            var x = 0
            while x < w {
                let tPass = d.grid[x, y-1].isPassable
                let bPass = d.grid[x, y  ].isPassable
                if !(tPass && bPass) { x += 1; continue }

                let tID = roomID[idx(x, y-1)]
                let bID = roomID[idx(x, y  )]
                let isRR = (tID >= 0 && bID >= 0 && tID != bID)
                let isRC = (tID >= 0) != (bID >= 0)
                if !(isRR || isRC) { x += 1; continue }

                let pairA = tID, pairB = bID
                let x0 = x
                var x1 = x
                while x1 + 1 < w {
                    let tP = d.grid[x1+1, y-1].isPassable
                    let bP = d.grid[x1+1, y  ].isPassable
                    if !(tP && bP) { break }
                    let t2 = roomID[idx(x1+1, y-1)], b2 = roomID[idx(x1+1, y)]
                    let rr2 = (t2 >= 0 && b2 >= 0 && t2 != b2)
                    let rc2 = (t2 >= 0) != (b2 >= 0)
                    if isRR && rr2 && samePair(pairA, pairB, t2, b2) { x1 += 1; continue }
                    if isRC && rc2 { x1 += 1; continue }
                    break
                }

                let span = x1 - x0 + 1
                let maxSpan = isRR ? policy.maxSpanRoomRoom : policy.maxSpanRoomCorridor
                if span <= maxSpan {
                    for xx in x0...x1 { edges[hx: xx, hy: y] = .door }
                }
                x = x1 + 1
            }
        }

        // 5) Rasterize door tiles from door edges (policy controls which side turns into .door)
        var grid = d.grid
        var doorTiles: [Point] = []

        // Vertical door edges at (vx: x, vy: y) separate (x-1,y) ↔ (x,y).
        for x in 1..<w {
            for y in 0..<h where edges[vx: x, vy: y] == .door {
                let li = idx(x-1, y), ri = idx(x, y)
                let lIsRoom = roomID[li] >= 0
                let rIsRoom = roomID[ri] >= 0
                if lIsRoom && rIsRoom {
                    if policy.rasterizeRoomRoomBothSides {
                        if grid[x-1, y] != .door { grid[x-1, y] = .door; doorTiles.append(Point(x-1, y)) }
                        if grid[x,   y] != .door { grid[x,   y] = .door; doorTiles.append(Point(x,   y)) }
                    } else {
                        if grid[x-1, y] != .door { grid[x-1, y] = .door; doorTiles.append(Point(x-1, y)) }
                    }
                } else if lIsRoom != rIsRoom {
                    if policy.rasterizeRoomCorridorRoomSideOnly {
                        let (rx, ry) = lIsRoom ? (x-1, y) : (x, y)
                        if grid[rx, ry] != .door { grid[rx, ry] = .door; doorTiles.append(Point(rx, ry)) }
                    } else {
                        if grid[x-1, y] != .door { grid[x-1, y] = .door; doorTiles.append(Point(x-1, y)) }
                        if grid[x,   y] != .door { grid[x,   y] = .door; doorTiles.append(Point(x,   y)) }
                    }
                }
            }
        }

        // Horizontal door edges at (hx: x, hy: y) separate (x,y-1) ↔ (x,y).
        for y in 1..<h {
            for x in 0..<w where edges[hx: x, hy: y] == .door {
                let ti = idx(x, y-1), bi = idx(x, y)
                let tIsRoom = roomID[ti] >= 0
                let bIsRoom = roomID[bi] >= 0
                if tIsRoom && bIsRoom {
                    if policy.rasterizeRoomRoomBothSides {
                        if grid[x, y-1] != .door { grid[x, y-1] = .door; doorTiles.append(Point(x, y-1)) }
                        if grid[x, y  ] != .door { grid[x, y  ] = .door; doorTiles.append(Point(x, y  )) }
                    } else {
                        if grid[x, y-1] != .door { grid[x, y-1] = .door; doorTiles.append(Point(x, y-1)) }
                    }
                } else if tIsRoom != bIsRoom {
                    if policy.rasterizeRoomCorridorRoomSideOnly {
                        let (rx, ry) = tIsRoom ? (x, y-1) : (x, y)
                        if grid[rx, ry] != .door { grid[rx, ry] = .door; doorTiles.append(Point(rx, ry)) }
                    } else {
                        if grid[x, y-1] != .door { grid[x, y-1] = .door; doorTiles.append(Point(x, y-1)) }
                        if grid[x, y  ] != .door { grid[x, y  ] = .door; doorTiles.append(Point(x, y  )) }
                    }
                }
            }
        }

        // Dedup door tiles in case vertical/horizontal passes touched the same cell
        if !doorTiles.isEmpty {
            var seen = Set<Int>(); seen.reserveCapacity(doorTiles.count)
            var unique: [Point] = []; unique.reserveCapacity(doorTiles.count)
            for p in doorTiles {
                let i = idx(p.x, p.y)
                if seen.insert(i).inserted { unique.append(p) }
            }
            doorTiles = unique
        }

        return (edges, grid, doorTiles)
    }
}

// MARK: - Edge-aware BFS (used for entrance/exit tagging)

fileprivate func edgeBFS(from start: Point, grid: Grid, edges: EdgeGrid) -> [Int] {
    let w = grid.width, h = grid.height, total = w * h
    @inline(__always) func idx(_ x: Int, _ y: Int) -> Int { y * w + x }

    var dist = Array(repeating: -1, count: total)

    // Validate start
    guard start.x >= 0, start.x < w, start.y >= 0, start.y < h,
          grid[start.x, start.y].isPassable else {
        return dist
    }

    let startIndex = idx(start.x, start.y)
    var q: [Int] = [startIndex]
    var head = 0
    dist[startIndex] = 0

    while head < q.count {
        let cur = q[head]; head += 1
        let x = cur % w, y = cur / w
        let base = dist[cur]

        forEachNeighbor(x, y, w, h, grid, edges) { nx, ny in
            let ni = idx(nx, ny)
            if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
        }
    }
    return dist
}

// MARK: - Small helpers

private extension EdgeType {
    var isTraversable: Bool {
        switch self {
        case .open, .door, .locked: return true
        case .wall:                 return false
        }
    }
}
