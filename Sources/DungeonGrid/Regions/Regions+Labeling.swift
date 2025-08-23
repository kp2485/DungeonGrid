//
//  Regions+Labeling.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public extension Regions {
    /// Label every passable cell with a RegionID matching `Regions.extractGraph`.
    /// - Returns: (labels, kinds, width, height)
    static func labelCells(_ d: Dungeon) -> (labels: [RegionID?], kinds: [RegionID: RegionKind], width: Int, height: Int) {
        let w = d.grid.width, h = d.grid.height, total = w*h
        @inline(__always) func idx(_ x:Int,_ y:Int)->Int { y*w + x }

        // Room membership: use room.id as marker
        var roomID = Array(repeating: -1, count: total)
        for room in d.rooms {
            for y in room.minY...room.maxY {
                for x in room.minX...room.maxX where d.grid[x,y].isPassable {
                    roomID[idx(x,y)] = room.id
                }
            }
        }

        var labels = Array<RegionID?>(repeating: nil, count: total)
        var kinds: [RegionID: RegionKind] = [:]
        var nextID = 1

        // Rooms (strictly within rect bounds)
        for room in d.rooms {
            let rid = RegionID(raw: nextID); nextID += 1
            kinds[rid] = .room(room.id)
            for y in room.minY...room.maxY {
                for x in room.minX...room.maxX where d.grid[x,y].isPassable {
                    labels[idx(x,y)] = rid
                }
            }
        }

        // Corridor components: flood fill across passable, non-room cells using edge constraints
        var seen = Array(repeating: false, count: total)
        for y0 in 0..<h {
            for x0 in 0..<w {
                let i0 = idx(x0,y0)
                if seen[i0] || !d.grid[x0,y0].isPassable || roomID[i0] >= 0 { continue }

                let rid = RegionID(raw: nextID); nextID += 1
                kinds[rid] = .corridor(rid.raw) // unique per component

                var q = [i0]; seen[i0] = true
                while let cur = q.popLast() {
                    labels[cur] = rid
                    let cx = cur % w, cy = cur / w

                    // left
                    if cx > 0 {
                        let n = cur - 1
                        if !seen[n], roomID[n] < 0, d.grid[cx-1,cy].isPassable, d.edges.canStep(from: cx, cy, to: cx-1, cy) {
                            seen[n] = true; q.append(n)
                        }
                    }
                    // right
                    if cx + 1 < w {
                        let n = cur + 1
                        if !seen[n], roomID[n] < 0, d.grid[cx+1,cy].isPassable, d.edges.canStep(from: cx, cy, to: cx+1, cy) {
                            seen[n] = true; q.append(n)
                        }
                    }
                    // up
                    if cy > 0 {
                        let n = cur - w
                        if !seen[n], roomID[n] < 0, d.grid[cx,cy-1].isPassable, d.edges.canStep(from: cx, cy, to: cx, cy-1) {
                            seen[n] = true; q.append(n)
                        }
                    }
                    // down
                    if cy + 1 < h {
                        let n = cur + w
                        if !seen[n], roomID[n] < 0, d.grid[cx,cy+1].isPassable, d.edges.canStep(from: cx, cy, to: cx, cy+1) {
                            seen[n] = true; q.append(n)
                        }
                    }
                }
            }
        }

        return (labels, kinds, w, h)
    }

    /// Convenience: the RegionID for a given passable point (or nil).
    static func regionID(at p: Point, labels: [RegionID?], width: Int) -> RegionID? {
        labels[p.y * width + p.x]
    }
}
