//
//  ContentPlanner.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public struct SpawnSpec: Sendable, Equatable {
    /// Label for this content kind, e.g. "enemy", "loot.gold".
    public var kind: String
    /// Allowed theme names for the region (empty = any).
    public var themeNames: Set<String>
    /// Required theme tags (must be a subset match). Empty = ignore.
    public var requireTags: [String: String]
    /// Standard placement policy (rooms/corridors, spacing, LOS, etc.)
    public var policy: PlacementPolicy

    public init(kind: String,
                themeNames: Set<String> = [],
                requireTags: [String: String] = [:],
                policy: PlacementPolicy = .init()) {
        self.kind = kind
        self.themeNames = themeNames
        self.requireTags = requireTags
        self.policy = policy
    }
}

public struct ContentPlan: Sendable, Equatable {
    public let placements: [Placement] // all kinds together
}

/// Theme-aware multi-spec planner. Deterministic. Avoids cross-kind overlaps.
public enum ContentPlanner {
    @discardableResult
    public static func planAll(in d: Dungeon,
                               graph g: RegionGraph,
                               themes: ThemeAssignment,
                               seed: UInt64,
                               specs: [SpawnSpec]) -> ContentPlan {
        
        // Use cached topology via DungeonIndex to avoid recomputing labels/graph.
        let index = DungeonIndex(d)
        let labels = index.labels
        let kinds  = index.kinds
        let w      = index.width
        let h      = index.height

        // Fast lookup for region theme matches
        @inline(__always)
        func regionAllowed(_ rid: RegionID?, for spec: SpawnSpec) -> Bool {
            guard let rid, let theme = themes.regionToTheme[rid] else {
                // If region has no theme, only allow when spec has no constraints
                return spec.themeNames.isEmpty && spec.requireTags.isEmpty
            }
            if !spec.themeNames.isEmpty && !spec.themeNames.contains(theme.name) { return false }
            if !spec.requireTags.isEmpty {
                for (k, v) in spec.requireTags where theme.tags[k] != v { return false }
            }
            return true
        }

        // Reusable LOS policy wrapper
        func losPolicy(for p: PlacementPolicy) -> VisibilityPolicy {
            .init(doorTransparent: p.doorsTransparentForLOS, diagonalThroughCorners: false)
        }

        // Optional BFS distance map from entrance
        var dist: [Int]? = nil
        if let s = d.entrance,
           specs.contains(where: { $0.policy.minDistanceFromEntrance != nil }) {
            dist = edgeBFS(from: s, grid: d.grid, edges: d.edges)
        }

        // Occupancy to prevent cross-spec overlaps
        var occupied = Set<Int>() // linear index y*w + x
        var out: [Placement] = []
        out.reserveCapacity(specs.reduce(0) { $0 + ($1.policy.count ?? 0) })

        var rng = SplitMix64(seed: seed ^ hashKind("ContentPlanner")) // deterministic base

        for spec in specs {
            // Derive a per-spec RNG to keep order deterministic yet stable
            var srng = SplitMix64(seed: rng.next() ^ hashKind(spec.kind))

            // Collect candidates under theme + region class + tile/door constraints
            var candidates: [Point] = []
            candidates.reserveCapacity(w*h/4)

            for y in 0..<h {
                for x in 0..<w {
                    let t = d.grid[x, y]
                    if !t.isPassable { continue }
                    if spec.policy.excludeDoorTiles && t == .door { continue }

                    let rid = labels[y * w + x]
                    // Region class check
                    switch spec.policy.regionClass {
                    case .any: break
                    case .roomsOnly:
                        guard let rid, case .room = kinds[rid] else { continue }
                    case .corridorsOnly:
                        guard let rid, case .corridor = kinds[rid] else { continue }
                    }
                    // Theme check
                    if !regionAllowed(rid, for: spec) { continue }

                    // Distance constraint
                    if let mind = spec.policy.minDistanceFromEntrance, let dist = dist {
                        let di = dist[y * w + x]
                        if di < 0 || di < mind { continue }
                    }

                    // LOS avoidance
                    if spec.policy.avoidLOSFromEntrance, let s = d.entrance {
                        if Visibility.hasLineOfSight(in: d, from: s, to: Point(x, y),
                                                     policy: losPolicy(for: spec.policy)) {
                            continue
                        }
                    }

                    candidates.append(Point(x, y))
                }
            }

            // Deterministic shuffle
            fisherYates(&candidates, rng: &srng)

            // Decide target count
            let targetCount: Int = {
                if let c = spec.policy.count { return max(0, min(c, candidates.count)) }
                if let dens = spec.policy.density {
                    return max(0, min(candidates.count, Int((dens * Double(candidates.count)).rounded())))
                }
                return min(10, candidates.count)
            }()

            // Greedy spacing + cross-spec collision check
            var chosen: [Point] = []
            chosen.reserveCapacity(targetCount)
            let spacing = spec.policy.minSpacing

            for p in candidates {
                if chosen.count == targetCount { break }
                let li = p.y * w + p.x
                if occupied.contains(li) { continue }

                if spacing > 0 {
                    var ok = true
                    for q in chosen {
                        if abs(p.x - q.x) + abs(p.y - q.y) < spacing { ok = false; break }
                    }
                    if !ok { continue }
                }

                chosen.append(p)
                occupied.insert(li)
            }

            // Emit with region ids
            for p in chosen {
                out.append(Placement(kind: spec.kind, position: p, region: labels[p.y * w + p.x]))
            }
        }

        return ContentPlan(placements: out)
    }

    // MARK: - Utilities

    /// Same BFS as elsewhere; duplicated locally for independence.
    private static func edgeBFS(from start: Point, grid: Grid, edges: EdgeGrid) -> [Int] {
        let w = grid.width, h = grid.height, total = w*h
        var dist = Array(repeating: -1, count: total)
        guard grid[start.x, start.y].isPassable else { return dist }
        var q = [start.y*w + start.x]; dist[q[0]] = 0
        var i = 0
        while i < q.count {
            let cur = q[i]; i += 1
            let x = cur % w, y = cur / w, base = dist[cur]
            if x > 0, grid[x-1,y].isPassable, edges.canStep(from: x, y, to: x-1, y) {
                let ni = y*w + (x-1); if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
            }
            if x + 1 < w, grid[x+1,y].isPassable, edges.canStep(from: x, y, to: x+1, y) {
                let ni = y*w + (x+1); if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
            }
            if y > 0, grid[x,y-1].isPassable, edges.canStep(from: x, y, to: x, y-1) {
                let ni = (y-1)*w + x; if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
            }
            if y + 1 < h, grid[x,y+1].isPassable, edges.canStep(from: x, y, to: x, y+1) {
                let ni = (y+1)*w + x; if dist[ni] < 0 { dist[ni] = base + 1; q.append(ni) }
            }
        }
        return dist
    }

    private static func fisherYates<T>(_ a: inout [T], rng: inout SplitMix64) {
        guard a.count > 1 else { return }
        for i in stride(from: a.count - 1, through: 1, by: -1) {
            let j = rng.int(in: 0...i)
            if i != j { a.swapAt(i, j) }
        }
    }

    /// Stable 64-bit hash for seeding from a string (FNV-1a).
    private static func hashKind(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h ^= UInt64(b); h &*= 0x00000100000001B3 }
        return h
    }
}
