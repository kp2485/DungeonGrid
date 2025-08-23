//
//  RegionExtractor.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public enum Regions {
    /// Build a room/corridor region graph from the dungeon’s tiles + edges.
    /// - Rooms become their own regions (exactly the room rect interior).
    /// - Remaining passable tiles are grouped into corridor components via edge-aware flood fill.
    public static func extractGraph(_ d: Dungeon) -> RegionGraph {
        let w = d.grid.width, h = d.grid.height, total = w * h
        @inline(__always) func idx(_ x:Int,_ y:Int)->Int { y*w + x }

        // --- 1) Mark passable cells that lie inside any room rect
        var inRoom = Array(repeating: false, count: total)
        for room in d.rooms {
            for y in room.minY...room.maxY {
                for x in room.minX...room.maxX where d.grid[x, y].isPassable {
                    inRoom[idx(x, y)] = true
                }
            }
        }

        // --- 2) Assign RegionIDs and label cells
        var labels = Array<RegionID?>(repeating: nil, count: total)
        var nodes: [RegionID: RegionNode] = [:]
        var nextRID = 1

        // Rooms: one region per room, limited strictly to its rect
        for room in d.rooms {
            let rid = RegionID(raw: nextRID); nextRID += 1
            var tileCount = 0
            var minX = room.maxX, minY = room.maxY, maxX = room.minX, maxY = room.minY
            for y in room.minY...room.maxY {
                for x in room.minX...room.maxX where d.grid[x, y].isPassable {
                    labels[idx(x, y)] = rid
                    tileCount += 1
                    if x < minX { minX = x }; if x > maxX { maxX = x }
                    if y < minY { minY = y }; if y > maxY { maxY = y }
                }
            }
            let center = Point(room.rect.midX, room.rect.midY)
            let bbox = Rect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
            nodes[rid] = RegionNode(id: rid, kind: .room(room.id), tileCount: tileCount, bbox: bbox, center: center)
        }

        // Corridors: flood-fill across passable cells not inside rooms, using edge gates
        var corridorIndex = 0
        var seen = Array(repeating: false, count: total)

        for y0 in 0..<h {
            for x0 in 0..<w {
                let i0 = idx(x0, y0)
                if seen[i0] || !d.grid[x0, y0].isPassable || inRoom[i0] { continue }

                let rid = RegionID(raw: nextRID); nextRID += 1
                var tileCount = 0
                var minX = x0, maxX = x0, minY = y0, maxY = y0
                var q = [i0]; seen[i0] = true

                while let cur = q.popLast() {
                    let cx = cur % w, cy = cur / w
                    labels[cur] = rid
                    tileCount += 1
                    if cx < minX { minX = cx }; if cx > maxX { maxX = cx }
                    if cy < minY { minY = cy }; if cy > maxY { maxY = cy }

                    // Explore 4-neighbors through passable edges, remain outside rooms
                    // left
                    if cx > 0 {
                        let n = cur - 1
                        if !seen[n], !inRoom[n], d.grid[cx-1, cy].isPassable, d.edges.canStep(from: cx, cy, to: cx-1, cy) {
                            seen[n] = true; q.append(n)
                        }
                    }
                    // right
                    if cx + 1 < w {
                        let n = cur + 1
                        if !seen[n], !inRoom[n], d.grid[cx+1, cy].isPassable, d.edges.canStep(from: cx, cy, to: cx+1, cy) {
                            seen[n] = true; q.append(n)
                        }
                    }
                    // up
                    if cy > 0 {
                        let n = cur - w
                        if !seen[n], !inRoom[n], d.grid[cx, cy-1].isPassable, d.edges.canStep(from: cx, cy, to: cx, cy-1) {
                            seen[n] = true; q.append(n)
                        }
                    }
                    // down
                    if cy + 1 < h {
                        let n = cur + w
                        if !seen[n], !inRoom[n], d.grid[cx, cy+1].isPassable, d.edges.canStep(from: cx, cy, to: cx, cy+1) {
                            seen[n] = true; q.append(n)
                        }
                    }
                }

                let bbox = Rect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
                // centroid-ish integer center
                let center = Point((minX + maxX) / 2, (minY + maxY) / 2)
                nodes[rid] = RegionNode(id: rid, kind: .corridor(corridorIndex), tileCount: tileCount, bbox: bbox, center: center)
                corridorIndex += 1
            }
        }

        // --- 3) Aggregate boundary edges between *different* regions
        struct PairKey: Hashable { let a: RegionID; let b: RegionID }
        var agg: [PairKey: (open: Int, door: Int)] = [:]

        // Vertical boundaries (between (x-1,y) and (x,y)) – skip outer frame (x ∈ 1...w-1)
        for y in 0..<h {
            for x in 1..<w {
                let aIdx = idx(x-1, y), bIdx = idx(x, y)
                guard let ra = labels[aIdx], let rb = labels[bIdx], ra != rb else { continue }
                let e = d.edges[vx: x, vy: y]
                switch e {
                case .open:
                    let key = ra.raw < rb.raw ? PairKey(a: ra, b: rb) : PairKey(a: rb, b: ra)
                    let cur = agg[key] ?? (0, 0); agg[key] = (cur.open + 1, cur.door)
                case .door:
                    let key = ra.raw < rb.raw ? PairKey(a: ra, b: rb) : PairKey(a: rb, b: ra)
                    let cur = agg[key] ?? (0, 0); agg[key] = (cur.open, cur.door + 1)
                case .wall, .locked:
                    continue
                }
            }
        }

        // Horizontal boundaries (between (x,y-1) and (x,y)) – skip outer frame (y ∈ 1...h-1)
        for x in 0..<w {
            for y in 1..<h {
                let aIdx = idx(x, y-1), bIdx = idx(x, y)
                guard let ra = labels[aIdx], let rb = labels[bIdx], ra != rb else { continue }
                let e = d.edges[hx: x, hy: y]
                switch e {
                case .open:
                    let key = ra.raw < rb.raw ? PairKey(a: ra, b: rb) : PairKey(a: rb, b: ra)
                    let cur = agg[key] ?? (0, 0); agg[key] = (cur.open + 1, cur.door)
                case .door:
                    let key = ra.raw < rb.raw ? PairKey(a: ra, b: rb) : PairKey(a: rb, b: ra)
                    let cur = agg[key] ?? (0, 0); agg[key] = (cur.open, cur.door + 1)
                case .wall, .locked:
                    continue
                }
            }
        }

        // --- 4) Materialize edges and adjacency
        var edges: [RegionEdge] = []
        edges.reserveCapacity(agg.count)
        var adj: [RegionID: [RegionID]] = [:]

        for (key, cnt) in agg {
            let re = RegionEdge(a: key.a, b: key.b, openCount: cnt.open, doorCount: cnt.door)
            edges.append(re)
            adj[key.a, default: []].append(key.b)
            adj[key.b, default: []].append(key.a)
        }

        return RegionGraph(nodes: nodes, edges: edges, adjacency: adj)
    }
}
