//
//  Placer.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public enum Placer {

    /// Back-compat convenience that avoids recomputing labels/graph.
    /// Internally forwards to the index-based implementation.
    public static func plan(in d: Dungeon,
                            seed: UInt64,
                            kind: String,
                            policy: PlacementPolicy) -> [Placement] {
        let index = DungeonIndex(d)
        return plan(in: d, index: index, seed: seed, kind: kind, policy: policy)
    }

    /// Plan placements using a cached DungeonIndex (avoids recomputing labels/kinds).
    public static func plan(in d: Dungeon,
                            index: DungeonIndex,
                            seed: UInt64,
                            kind: String,
                            policy: PlacementPolicy) -> [Placement] {
        let w = d.grid.width, h = d.grid.height
        let labels = index.labels
        let kinds  = index.kinds

        // Collect candidate tiles
        var candidates: [Point] = []
        candidates.reserveCapacity(w * h / 2)

        func regionClassOK(_ rid: RegionID?) -> Bool {
            switch policy.regionClass {
            case .any: return true
            case .roomsOnly:
                guard let rid = rid, let kind = kinds[rid] else { return false }
                if case .room = kind { return true } else { return false }
            case .corridorsOnly:
                guard let rid = rid, let kind = kinds[rid] else { return false }
                if case .corridor = kind { return true } else { return false }
            }
        }

        for y in 0..<h {
            for x in 0..<w {
                let t = d.grid[x, y]
                if !t.isPassable { continue }
                if policy.excludeDoorTiles && t == .door { continue }
                let rid = labels[y * w + x]
                if !regionClassOK(rid) { continue }
                candidates.append(Point(x, y))
            }
        }

        // Optional distance constraint (edge-aware BFS from entrance)
        var dist: [Int]? = nil
        if let s = d.entrance, policy.minDistanceFromEntrance != nil {
            dist = edgeBFS(from: s, grid: d.grid, edges: d.edges)
        }

        // Optional LOS avoidance from entrance
        let losPolicy = VisibilityPolicy(doorTransparent: policy.doorsTransparentForLOS,
                                         diagonalThroughCorners: false)

        // Filter candidates by constraints
        let filtered: [Point] = candidates.filter { p in
            if let mind = policy.minDistanceFromEntrance, let dist = dist {
                let di = dist[p.y * w + p.x]
                if di < 0 || di < mind { return false }
            }
            if policy.avoidLOSFromEntrance, let s = d.entrance {
                if Visibility.hasLineOfSight(in: d, from: s, to: p, policy: losPolicy) {
                    return false
                }
            }
            return true
        }

        // Deterministic shuffle (SplitMix64)
        var rng = SplitMix64(seed: seed ^ 0xC0FFEE_BEEF_1234)
        var shuffled = filtered
        fisherYatesShuffle(&shuffled, rng: &rng)

        // Decide how many to place
        let targetCount: Int = {
            if let c = policy.count { return max(0, c) }
            if let dens = policy.density {
                return max(0, min(shuffled.count, Int((dens * Double(shuffled.count)).rounded())))
            }
            return min(10, shuffled.count) // sensible default
        }()

        // Greedy spacing
        var chosen: [Point] = []
        chosen.reserveCapacity(targetCount)
        for p in shuffled {
            if chosen.count == targetCount { break }
            if policy.minSpacing > 0 {
                var ok = true
                for q in chosen {
                    let manhattan = abs(p.x - q.x) + abs(p.y - q.y)
                    if manhattan < policy.minSpacing { ok = false; break }
                }
                if !ok { continue }
            }
            chosen.append(p)
        }

        // Stitch region ids onto placements
        return chosen.map {
            let rid = labels[$0.y * w + $0.x]
            return Placement(kind: kind, position: $0, region: rid)
        }
    }
    
    /// Batch-plan multiple kinds with a shared DungeonIndex (avoids redundant topology work).
    public static func planMany(in d: Dungeon,
                                index: DungeonIndex,
                                requests: [PlacementRequest]) -> [String: [Placement]] {
        var out: [String: [Placement]] = [:]
        out.reserveCapacity(requests.count)
        for r in requests {
            let ps = plan(in: d, index: index, seed: r.seed, kind: r.kind, policy: r.policy)
            if out[r.kind] != nil { out[r.kind]! += ps } else { out[r.kind] = ps }
        }
        return out
    }

    // MARK: - Utilities

    private static func fisherYatesShuffle<T>(_ a: inout [T], rng: inout SplitMix64) {
        if a.count <= 1 { return }
        for i in stride(from: a.count - 1, through: 1, by: -1) {
            let j = rng.int(in: 0...i)
            if i != j { a.swapAt(i, j) }
        }
    }

    /// Edge-aware BFS distances (like the one used for entrance/exit tagging).
    private static func edgeBFS(from start: Point, grid: Grid, edges: EdgeGrid) -> [Int] {
        let w = grid.width, h = grid.height, total = w * h
        var dist = Array(repeating: -1, count: total)

        // validate start
        guard start.x >= 0 && start.x < w && start.y >= 0 && start.y < h,
              grid[start.x, start.y].isPassable else {
            return dist
        }

        @inline(__always) func idx(_ x: Int, _ y: Int) -> Int { y * w + x }

        var q: [Int] = []
        q.reserveCapacity(total / 4)
        let s = idx(start.x, start.y)
        dist[s] = 0
        q.append(s)

        var head = 0
        while head < q.count {
            let cur = q[head]; head += 1
            let x = cur % w, y = cur / w
            let base = dist[cur]

            // unified, edge-aware neighbors
            forEachNeighbor(x, y, w, h, grid, edges) { nx, ny in
                let ni = idx(nx, ny)
                if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
            }
        }
        return dist
    }
}
