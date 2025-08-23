//
//  Placer.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public enum Placer {

    /// Plan placements according to a policy; deterministic given `seed`.
    /// - Parameters:
    ///   - d: dungeon
    ///   - seed: PRNG seed for determinism
    ///   - kind: a string tag for what’s being placed ("enemy", "loot.health", etc.)
    ///   - policy: constraints (rooms/corridors, spacing, LOS, etc.)
    /// - Returns: placements (positions + region ids)
    public static func plan(in d: Dungeon,
                            seed: UInt64,
                            kind: String,
                            policy: PlacementPolicy) -> [Placement] {
        let w = d.grid.width, h = d.grid.height
        let (labels, kinds, _, _) = Regions.labelCells(d)

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
        candidates = candidates.filter { p in
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
        fisherYatesShuffle(&candidates, rng: &rng)

        // Decide how many to place
        let targetCount: Int = {
            if let c = policy.count { return max(0, c) }
            if let dens = policy.density {
                return max(0, min(candidates.count, Int((dens * Double(candidates.count)).rounded())))
            }
            return min(10, candidates.count) // sensible default
        }()

        // Greedy spacing
        var chosen: [Point] = []
        chosen.reserveCapacity(targetCount)
        for p in candidates {
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
        let w = grid.width, h = grid.height, total = w*h
        var dist = Array(repeating: -1, count: total)
        guard grid[start.x, start.y].isPassable else { return dist }
        var q = [start.y*w + start.x]; dist[q[0]] = 0

        while !q.isEmpty {
            let cur = q.removeFirst()
            let x = cur % w, y = cur / w, base = dist[cur]

            // left
            if x > 0, grid[x-1, y].isPassable, edges.canStep(from: x, y, to: x-1, y) {
                let ni = y*w + (x-1); if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
            }
            // right
            if x + 1 < w, grid[x+1, y].isPassable, edges.canStep(from: x, y, to: x+1, y) {
                let ni = y*w + (x+1); if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
            }
            // up
            if y > 0, grid[x, y-1].isPassable, edges.canStep(from: x, y, to: x, y-1) {
                let ni = (y-1)*w + x; if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
            }
            // down
            if y + 1 < h, grid[x, y+1].isPassable, edges.canStep(from: x, y, to: x, y+1) {
                let ni = (y+1)*w + x; if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
            }
        }
        return dist
    }
}