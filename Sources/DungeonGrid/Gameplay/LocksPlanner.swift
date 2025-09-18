//
//  LocksPlanner.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct LocksPlan: Sendable, Equatable {
    public struct Lock: Sendable, Equatable {
        public let regionA: RegionID
        public let regionB: RegionID
        /// Region where the key should be placed (reachable before crossing the lock).
        public let keyRegion: RegionID
    }
    public let locks: [Lock]
}

public enum LocksPlanner {
    /// Choose up to `maxLocks` region-tree edges to lock and return a new Dungeon with those
    /// door edges converted to `.locked`, plus a plan of where to place keys.
    ///
    /// Strategy:
    /// 1) Build a minimum spanning tree (Prim) with door-biased weights.
    /// 2) Root it at the **entrance region**, then lock some parent→child edges along the tree.
    /// 3) Place each key in the parent side (reachable before the lock).
    ///
    /// Notes:
    /// - Only locks edges that currently have at least one `.door` boundary; open-only boundaries are left alone.
    /// - Deterministic given the dungeon and `maxLocks` (no RNG).
    @discardableResult
    public static func planAndApply(_ d: Dungeon,
                                    graph g: RegionGraph,
                                    entrance: Point?,
                                    maxLocks: Int = 2,
                                    doorBias: Int = 2,
                                    preferDeepLocks: Bool = false,
                                    minKeyDepth: Int = 0,
                                    chain: Bool = false) -> (dungeon: Dungeon, plan: LocksPlan) {

        let index  = DungeonIndex(d)
        let labels = index.labels
        let w      = index.width
        let h      = index.height
        @inline(__always) func idx(_ x:Int,_ y:Int)->Int { y*w + x }

        // 1) Pick entrance region (fallback to first room center)
        let startPoint: Point = {
            if let s = entrance { return s }
            if let r = d.rooms.first { return Point(r.rect.midX, r.rect.midY) }
            return Point(1,1)
        }()
        guard let startRegion = Regions.regionID(at: startPoint, labels: labels, width: w) else {
            return (d, LocksPlan(locks: []))
        }

        // 2) Build MST over region graph using RegionEdge.weight(doorBias:)
        var inTree = Set<RegionID>()
        var parent: [RegionID: RegionID] = [:]
        var bestW: [RegionID: Int] = [:]
        var bestEdgeFrom: [RegionID: RegionID] = [:]
        var adj: [RegionID: [(RegionID, Int)]] = [:]
        for e in g.edges {
            let w = e.weight(doorBias: doorBias)
            adj[e.a, default: []].append((e.b, w))
            adj[e.b, default: []].append((e.a, w))
        }

        // Prim
        var heap = MinHeap()
        inTree.insert(startRegion)
        for (v, w) in adj[startRegion] ?? [] {
            bestW[v] = w; bestEdgeFrom[v] = startRegion
            heap.push(priority: w, value: v.raw)
        }
        while let (_, raw) = heap.pop() {
            let v = RegionID(raw: raw)
            if inTree.contains(v) { continue }
            // Accept edge
            guard let u = bestEdgeFrom[v] else { continue }
            inTree.insert(v); parent[v] = u
            // Relax neighbors
            for (to, w) in adj[v] ?? [] where !inTree.contains(to) {
                if w < (bestW[to] ?? Int.max) {
                    bestW[to] = w; bestEdgeFrom[to] = v
                    heap.push(priority: w, value: to.raw)
                }
            }
        }

        // 3) Candidate tree edges: parent[v] -> v for all v != root
        var treeEdges: [(RegionID, RegionID)] = []
        for (v, u) in parent { treeEdges.append((u, v)) }

        // Compute depth per region in the tree (root depth = 0)
        var depth: [RegionID: Int] = [:]
        depth[startRegion] = 0
        // BFS over tree to assign depths
        var q: [RegionID] = [startRegion]
        var idxQ = 0
        while idxQ < q.count {
            let u = q[idxQ]; idxQ += 1
            let du = depth[u] ?? 0
            for (v, p) in parent where p == u {
                depth[v] = du + 1
                q.append(v)
            }
        }

        // 4) Pick up to `maxLocks` edges that actually have DOOR boundaries
        func hasDoorBoundary(_ a: RegionID, _ b: RegionID) -> Bool {
            // Scan grid boundaries once; early exit on first door match
            // Vertical boundaries
            for y in 0..<h {
                for x in 1..<w where d.edges[vx: x, vy: y] == .door {
                    let la = labels[idx(x-1,y)], rb = labels[idx(x,y)]
                    if la == nil || rb == nil { continue }
                    if (la! == a && rb! == b) || (la! == b && rb! == a) { return true }
                }
            }
            // Horizontal boundaries
            for x in 0..<w {
                for y in 1..<h where d.edges[hx: x, hy: y] == .door {
                    let ta = labels[idx(x,y-1)], bb = labels[idx(x,y)]
                    if ta == nil || bb == nil { continue }
                    if (ta! == a && bb! == b) || (ta! == b && bb! == a) { return true }
                }
            }
            return false
        }

        var chosen: [(RegionID, RegionID)] = []
        if chain {
            // Find deepest leaf by depth, then walk back toward root choosing edges
            let leaf: RegionID? = depth.max(by: { $0.value < $1.value })?.key
            if let leaf = leaf {
                var cur = leaf
                while let p = parent[cur] {
                    // Candidate edge p -> cur
                    if (depth[p] ?? 0) >= minKeyDepth && hasDoorBoundary(p, cur) {
                        chosen.append((p, cur))
                        if chosen.count == maxLocks { break }
                    }
                    cur = p
                }
            }
        } else {
            // Non-chained: optionally sort by depth of child (prefer deeper locks)
            let sorted = preferDeepLocks
                ? treeEdges.sorted { (a, b) in (depth[a.1] ?? 0) > (depth[b.1] ?? 0) }
                : treeEdges
            for (u, v) in sorted {
                if (depth[u] ?? 0) >= minKeyDepth && hasDoorBoundary(u, v) {
                    chosen.append((u, v))
                    if chosen.count == maxLocks { break }
                }
            }
        }

        if chosen.isEmpty {
            return (d, LocksPlan(locks: []))
        }

        // 5) Apply: convert door edges on selected region boundaries to .locked
        var edges = d.edges
        func lockBoundary(_ a: RegionID, _ b: RegionID) {
            // Vertical
            for y in 0..<h {
                for x in 1..<w where edges[vx: x, vy: y] == .door {
                    let la = labels[idx(x-1,y)], rb = labels[idx(x,y)]
                    if la == nil || rb == nil { continue }
                    if (la! == a && rb! == b) || (la! == b && rb! == a) {
                        edges[vx: x, vy: y] = .locked
                    }
                }
            }
            // Horizontal
            for x in 0..<w {
                for y in 1..<h where edges[hx: x, hy: y] == .door {
                    let ta = labels[idx(x,y-1)], bb = labels[idx(x,y)]
                    if ta == nil || bb == nil { continue }
                    if (ta! == a && bb! == b) || (ta! == b && bb! == a) {
                        edges[hx: x, hy: y] = .locked
                    }
                }
            }
        }

        for (u, v) in chosen { lockBoundary(u, v) }

        // 6) Build key placement plan: put each key in the "parent" side (u) region
        let planLocks: [LocksPlan.Lock] = chosen.map { .init(regionA: $0.0, regionB: $0.1, keyRegion: $0.0) }
        let plan = LocksPlan(locks: planLocks)

        let out = Dungeon(grid: d.grid, rooms: d.rooms, seed: d.seed,
                          doors: d.doors, entrance: d.entrance, exit: d.exit,
                          edges: edges)
        return (out, plan)
    }
}
