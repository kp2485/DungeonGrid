//
//  Placer.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

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
        let graph  = index.graph

        // Collect candidate tiles
        var candidates: [Point] = []
        candidates.reserveCapacity(w * h / 2)

        func regionClassOK(_ rid: RegionID?) -> Bool {
            switch policy.regionClass {
            case .any:
                return true
            case .roomsOnly:
                guard let rid = rid, let kind = kinds[rid] else { return false }
                if case .room = kind { return true } else { return false }
            case .corridorsOnly:
                guard let rid = rid, let kind = kinds[rid] else { return false }
                if case .corridor = kind { return true } else { return false }
            case .junctions(let minDeg):
                guard let rid = rid, let ns = nodeStats[rid] else { return false }
                return ns.degree >= minDeg
            case .deadEnds:
                guard let rid = rid, let ns = nodeStats[rid] else { return false }
                return ns.isDeadEnd
            case .farFromEntrance(let minHops):
                guard let rid = rid, let ns = nodeStats[rid] else { return false }
                let d = ns.distanceFromEntrance ?? Int.max
                return d >= minHops
            case .nearEntrance(let maxHops):
                guard let rid = rid, let ns = nodeStats[rid] else { return false }
                if let d = ns.distanceFromEntrance { return d <= maxHops } else { return false }
            case .perimeter:
                guard let rid = rid, let node = graph.nodes[rid] else { return false }
                let w = d.grid.width, h = d.grid.height
                let r = node.bbox
                return r.x == 0 || r.y == 0 || (r.x + r.width) == w || (r.y + r.height) == h
            case .core:
                guard let rid = rid, let node = graph.nodes[rid] else { return false }
                let w = d.grid.width, h = d.grid.height
                let r = node.bbox
                let touchesBorder = r.x == 0 || r.y == 0 || (r.x + r.width) == w || (r.y + r.height) == h
                return !touchesBorder
            }
        }
        
        // Precompute region stats for constraints
        let stats = RegionAnalysis.computeStats(dungeon: d, graph: graph)
        let nodeStats = stats.nodes

        for y in 0..<h {
            for x in 0..<w {
                let t = d.grid[x, y]
                if !t.isPassable { continue }
                if policy.excludeDoorTiles && t == .door { continue }
                let rid = labels[y * w + x]
                if !regionClassOK(rid) { continue }
                // Region-based filters
                if let rid = rid, let ns = nodeStats[rid] {
                    // Overall area min/max
                    if let amin = policy.regionAreaMin, ns.area < amin { continue }
                    if let amax = policy.regionAreaMax, ns.area > amax { continue }
                    // Per-kind area constraints
                    if let kind = kinds[rid] {
                        switch kind {
                        case .room:
                            if let rmin = policy.roomAreaMin, ns.area < rmin { continue }
                            if let rmax = policy.roomAreaMax, ns.area > rmax { continue }
                        case .corridor:
                            if let cmin = policy.corridorAreaMin, ns.area < cmin { continue }
                            if let cmax = policy.corridorAreaMax, ns.area > cmax { continue }
                            if policy.requireDeadEnd && ns.isDeadEnd == false { continue }
                        }
                    }
                    // Degree constraints
                    if let dmin = policy.regionDegreeMin, ns.degree < dmin { continue }
                    if let dmax = policy.regionDegreeMax, ns.degree > dmax { continue }
                }
                candidates.append(Point(x, y))
            }
        }

        // Optional distance constraint (edge-aware BFS from entrance)
        var distFromEntrance: [Int]? = nil
        var distFromExit: [Int]? = nil
        if let s = d.entrance, (policy.minDistanceFromEntrance != nil || policy.maxDistanceFromEntrance != nil) {
            distFromEntrance = edgeBFS(from: s, grid: d.grid, edges: d.edges)
        }
        if let t = d.exit, (policy.minDistanceFromExit != nil || policy.maxDistanceFromExit != nil) {
            distFromExit = edgeBFS(from: t, grid: d.grid, edges: d.edges)
        }

        // Optional LOS avoidance from entrance
        let losPolicy = VisibilityPolicy(doorTransparent: policy.doorsTransparentForLOS,
                                         diagonalThroughCorners: false)

        // Filter candidates by constraints
        // Optional door-edge avoidance: build a quick mask of tiles within radius of any door edge
        var avoidMask: [Bool]? = nil
        if policy.avoidNearDoorEdgesRadius > 0 {
            avoidMask = Array(repeating: false, count: w*h)
            let R = policy.avoidNearDoorEdgesRadius
            // Vertical door edges at seam x in 1..W-1, between (x-1,y) and (x,y)
            for y in 0..<h {
                for vx in 1..<w where d.edges[vx: vx, vy: y] == .door {
                    // mark tiles in manhattan radius around (vx-1,y) and (vx,y)
                    for dy in -R...R {
                        for dx in -R...R where abs(dx) + abs(dy) <= R {
                            let p1x = vx-1+dx, p1y = y+dy
                            let p2x = vx+dx,   p2y = y+dy
                            if p1x>=0 && p1y>=0 && p1x<w && p1y<h { avoidMask![p1y*w + p1x] = true }
                            if p2x>=0 && p2y>=0 && p2x<w && p2y<h { avoidMask![p2y*w + p2x] = true }
                        }
                    }
                }
            }
            // Horizontal door edges at seam y in 1..H-1, between (x,y-1) and (x,y)
            for hy in 1..<h {
                for x in 0..<w where d.edges[hx: x, hy: hy] == .door {
                    for dy in -R...R {
                        for dx in -R...R where abs(dx) + abs(dy) <= R {
                            let p1x = x+dx, p1y = hy-1+dy
                            let p2x = x+dx, p2y = hy+dy
                            if p1x>=0 && p1y>=0 && p1x<w && p1y<h { avoidMask![p1y*w + p1x] = true }
                            if p2x>=0 && p2y>=0 && p2x<w && p2y<h { avoidMask![p2y*w + p2x] = true }
                        }
                    }
                }
            }
        }

        let filtered: [Point] = candidates.filter { p in
            if let mind = policy.minDistanceFromEntrance, let dist = distFromEntrance {
                let di = dist[p.y * w + p.x]
                if di < 0 || di < mind { return false }
            }
            if let maxd = policy.maxDistanceFromEntrance, let dist = distFromEntrance {
                let di = dist[p.y * w + p.x]
                if di < 0 || di > maxd { return false }
            }
            if let mind = policy.minDistanceFromExit, let dist = distFromExit {
                let di = dist[p.y * w + p.x]
                if di < 0 || di < mind { return false }
            }
            if let maxd = policy.maxDistanceFromExit, let dist = distFromExit {
                let di = dist[p.y * w + p.x]
                if di < 0 || di > maxd { return false }
            }
            if policy.avoidLOSFromEntrance, let s = d.entrance {
                if Visibility.hasLineOfSight(in: d, from: s, to: p, policy: losPolicy) {
                    return false
                }
            }
            if let mask = avoidMask, mask[p.y * w + p.x] { return false }
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
