//
//  RegionRouting.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public enum RegionRouting {
    /// Region-level A* with door-biased weights.
    /// Returns a list of RegionIDs from `start` to `goal` (inclusive), or nil if disconnected.
    public static func route(_ g: RegionGraph,
                             from start: RegionID,
                             to goal: RegionID,
                             doorBias: Int = 0) -> [RegionID]? {
        if start == goal { return [start] }
        // Build neighbors with weights on demand
        struct EdgeRef { let to: RegionID; let w: Int }
        var nbrs: [RegionID: [EdgeRef]] = [:]
        nbrs.reserveCapacity(g.adjacency.count)

        for e in g.edges {
            let w = e.weight(doorBias: doorBias)
            nbrs[e.a, default: []].append(.init(to: e.b, w: w))
            nbrs[e.b, default: []].append(.init(to: e.a, w: w))
        }

        // Dijkstra (A* heuristic is 0 since region centers aren't guaranteed Manhattan-admissible)
        var dist: [RegionID: Int] = [start: 0]
        var prev: [RegionID: RegionID] = [:]
        var heap = MinHeap()

        // Map RegionID.raw to a dense heap key for priorities; we can just push raw as "value"
        heap.push(priority: 0, value: start.raw)

        var visited = Set<RegionID>()
        while let (_, val) = heap.pop() {
            let u = RegionID(raw: val)
            if visited.contains(u) { continue }
            visited.insert(u)
            if u == goal { break }

            for e in nbrs[u] ?? [] {
                if visited.contains(e.to) { continue }
                let alt = (dist[u] ?? Int.max) + e.w
                if alt < (dist[e.to] ?? Int.max) {
                    dist[e.to] = alt
                    prev[e.to] = u
                    heap.push(priority: alt, value: e.to.raw)
                }
            }
        }

        guard visited.contains(goal) else { return nil }
        // Reconstruct
        var path = [goal]
        var cur = goal
        while let p = prev[cur] {
            path.append(p); cur = p
        }
        return path.reversed()
    }

    /// Convenience: route by points, using a fresh label map to find their regions.
    public static func routePoints(_ d: Dungeon,
                                   _ g: RegionGraph,
                                   from: Point,
                                   to: Point,
                                   doorBias: Int = 0) -> [RegionID]? {
        let (labels, _, w, _) = Regions.labelCells(d)
        guard let rs = Regions.regionID(at: from, labels: labels, width: w),
              let rt = Regions.regionID(at: to,   labels: labels, width: w) else { return nil }
        return route(g, from: rs, to: rt, doorBias: doorBias)
    }
}