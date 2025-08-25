//
//  DungeonPipeline.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  A small, fluent pipeline to compose post-generation steps like connectivity,
//  door placement, locks planning, theming, and placements.
//  Steps are deterministic given the provided seed(s).
//

import Foundation

public struct DungeonPipelineResult: Sendable {
    public var dungeon: Dungeon
    public var locksPlan: LocksPlan? = nil
    public var themeAssignment: ThemeAssignment? = nil
    /// Placements bucketed by `kind` (e.g., "enemy", "loot.health")
    public var placements: [String: [Placement]] = [:]

    public init(dungeon: Dungeon) { self.dungeon = dungeon }
}

public struct DungeonPipeline: Sendable {
    public typealias Step = (_ res: inout DungeonPipelineResult) -> Void

    private let base: Dungeon
    private let steps: [Step]

    public init(base: Dungeon) {
        self.base = base
        self.steps = []
    }

    private init(base: Dungeon, steps: [Step]) {
        self.base = base
        self.steps = steps
    }

    // MARK: - Builder

    /// Ensure the dungeon is a single connected component (idempotent).
    public func ensureConnected(seed: UInt64) -> DungeonPipeline {
        adding { res in
            res.dungeon = Connectivity.ensureConnected(res.dungeon, seed: seed)
        }
    }

    /// Convert narrow region boundaries to door edges, rasterize door tiles, tag entrance/exit.
    public func placeDoors(seed: UInt64, policy: DoorPolicy = .init()) -> DungeonPipeline {
        adding { res in
            res.dungeon = EdgeDoors.placeDoorsAndTag(res.dungeon, seed: seed, policy: policy)
        }
    }

    /// Plan locks across region graph (updates edges) and return plan.
    public func planLocks(maxLocks: Int = 2, doorBias: Int = 2) -> DungeonPipeline {
        adding { res in
            let index = DungeonIndex(res.dungeon)
            let (d2, plan) = LocksPlanner.planAndApply(res.dungeon,
                                                       graph: index.graph,
                                                       entrance: res.dungeon.entrance,
                                                       maxLocks: maxLocks,
                                                       doorBias: doorBias)
            res.dungeon = d2
            res.locksPlan = plan
        }
    }

    /// Compute a theme assignment over the region graph (does not mutate the dungeon).
    public func theme(seed: UInt64, rules: [ThemeRule]) -> DungeonPipeline {
        adding { res in
            let index = DungeonIndex(res.dungeon)
            let assign = Themer.assignThemes(dungeon: res.dungeon, index: index, seed: seed, rules: rules)
            res.themeAssignment = assign
        }
    }

    /// Plan placements for a given kind/policy (does not mutate the dungeon).
    public func place(kind: String, policy: PlacementPolicy, seed: UInt64) -> DungeonPipeline {
        adding { res in
            let index = DungeonIndex(res.dungeon)
            let ps = Placer.plan(in: res.dungeon, index: index, seed: seed, kind: kind, policy: policy)
            if res.placements[kind] != nil { res.placements[kind]! += ps } else { res.placements[kind] = ps }
        }
    }

    // MARK: - Run

    @discardableResult
    public func run() -> DungeonPipelineResult {
        var out = DungeonPipelineResult(dungeon: base)
        for step in steps { step(&out) }
        return out
    }

    // MARK: - Internals

    private func adding(_ s: @escaping Step) -> DungeonPipeline {
        DungeonPipeline(base: base, steps: steps + [s])
    }
}

public extension DungeonPipeline {
    /// Convenience when placement heuristics want a single passage policy.
    func place(kind: String,
               policy: PlacementPolicy,
               passage: PassagePolicy,
               seed: UInt64) -> DungeonPipeline {
        adding { res in
            let index = DungeonIndex(res.dungeon)
            // If/when you thread passage into Placer, forward it here.
            // For now we still call existing Placer API (policy handles LOS knobs already).
            let ps = Placer.plan(in: res.dungeon,
                                 index: index,
                                 seed: seed,
                                 kind: kind,
                                 policy: policy)
            if res.placements[kind] != nil { res.placements[kind]! += ps } else { res.placements[kind] = ps }
        }
    }
}
