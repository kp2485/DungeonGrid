//
//  Themer.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public enum Themer {

    /// Assign themes to regions that match any rule. First matching rule wins (in the given order).
    /// Deterministic given `seed`, graph, and rules.
    public static func assignThemes(dungeon d: Dungeon,
                                    graph g: RegionGraph,
                                    stats s: RegionStats,
                                    seed: UInt64,
                                    rules: [ThemeRule]) -> ThemeAssignment {
        var rng = SplitMix64(seed: seed ^ 0x51_4D_54_68_4D)
        var out: [RegionID: Theme] = [:]

        for (rid, node) in g.nodes {
            guard let st = s.nodes[rid] else { continue }
            // determine region class
            let rClass: ThemeRule.RegionClass = {
                switch node.kind {
                case .room:     return .room
                case .corridor: return .corridor
                }
            }()

            // find first matching rule
            var picked: Theme? = nil
            for rule in rules {
                if rule.regionClass != .any && rule.regionClass != rClass { continue }
                if let minA = rule.minArea, st.area < minA { continue }
                if let maxA = rule.maxArea, st.area > maxA { continue }
                if let minD = rule.minDegree, st.degree < minD { continue }
                if let maxD = rule.maxDegree, st.degree > maxD { continue }
                if let de = rule.deadEndOnly {
                    if de && !st.isDeadEnd { continue }
                    if !de && st.isDeadEnd { continue }
                }
                if let mind = rule.minDistanceFromEntrance {
                    guard let dfe = st.distanceFromEntrance, dfe >= mind else { continue }
                }
                // choose theme deterministically
                picked = choose(rule.options, weights: rule.weights, rng: &rng)
                break
            }

            if let theme = picked {
                out[rid] = theme
            }
        }

        return ThemeAssignment(regionToTheme: out)
    }

    // MARK: - Deterministic weighted choice

    private static func choose(_ options: [Theme], weights: [Int]?, rng: inout SplitMix64) -> Theme {
        guard !options.isEmpty else { return Theme("none") }
        if let w = weights, w.count == options.count {
            let total = max(1, w.reduce(0, +))
            let pick = rng.int(in: 0...(total - 1))
            var acc = 0
            for (i, wi) in w.enumerated() {
                acc += max(0, wi)
                if pick < acc { return options[i] }
            }
            return options.last!
        } else {
            let i = rng.int(in: 0...(options.count - 1))
            return options[i]
        }
    }
}