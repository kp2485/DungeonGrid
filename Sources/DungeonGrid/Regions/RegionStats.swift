//
//  RegionStats.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct RegionStats: Sendable {
    public struct NodeStats: Sendable {
        public let id: RegionID
        public let area: Int              // tileCount
        public let degree: Int            // neighbors in region graph
        public let distanceFromEntrance: Int? // BFS hops in region graph; nil if no entrance or unreachable
        public let isDeadEnd: Bool        // degree == 1 (corridor dead ends are interesting)
    }
    public let nodes: [RegionID: NodeStats]
}

public enum RegionAnalysis {
    /// Compute per-region stats using the region graph.
    /// Distance is region-graph BFS hops from the entrance's region (if any).
    public static func computeStats(dungeon d: Dungeon, graph g: RegionGraph) -> RegionStats {
        // Degree from adjacency
        var degree: [RegionID: Int] = [:]
        for (k, ns) in g.adjacency { degree[k] = ns.count }

        // Entrance region (if any)
        let (labels, _, w, _) = Regions.labelCells(d)
        var entranceRID: RegionID? = nil
        if let s = d.entrance {
            entranceRID = Regions.regionID(at: s, labels: labels, width: w)
        }

        // BFS distances over region graph
        var dist: [RegionID: Int] = [:]
        if let start = entranceRID {
            var q: [RegionID] = [start]
            dist[start] = 0
            var i = 0
            while i < q.count {
                let u = q[i]; i += 1
                for v in g.adjacency[u] ?? [] {
                    if dist[v] == nil {
                        dist[v] = (dist[u] ?? 0) + 1
                        q.append(v)
                    }
                }
            }
        }

        // Assemble stats
        var out: [RegionID: RegionStats.NodeStats] = [:]
        out.reserveCapacity(g.nodes.count)
        for (rid, node) in g.nodes {
            let deg = degree[rid] ?? 0
            let isDE = deg == 1 // works for rooms/corridors; typically interesting for corridors
            let dval = dist[rid]
            out[rid] = RegionStats.NodeStats(
                id: rid,
                area: node.tileCount,
                degree: deg,
                distanceFromEntrance: dval,
                isDeadEnd: isDE
            )
        }
        return RegionStats(nodes: out)
    }
}