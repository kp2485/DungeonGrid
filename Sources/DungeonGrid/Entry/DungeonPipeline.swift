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
    /// Optional metrics captured during the run.
    public var metrics: DungeonPipelineMetrics? = nil

    public init(dungeon: Dungeon) { self.dungeon = dungeon }
}

public struct DungeonPipeline {
    public typealias Step = (_ res: inout DungeonPipelineResult) -> Void

    private let base: Dungeon
    private let steps: [Step]
    private let names: [String]

    public init(base: Dungeon) {
        self.base = base
        self.steps = []
        self.names = []
    }

    private init(base: Dungeon, steps: [Step], names: [String]) {
        self.base = base
        self.steps = steps
        self.names = names
    }

    // MARK: - Builder

    /// Ensure the dungeon is a single connected component (idempotent).
    public func ensureConnected(seed: UInt64) -> DungeonPipeline {
        addingNamed("ensureConnected") { res in
            res.dungeon = Connectivity.ensureConnected(res.dungeon, seed: seed)
        }
    }

    /// Convert narrow region boundaries to door edges, rasterize door tiles, tag entrance/exit.
    public func placeDoors(seed: UInt64, policy: DoorPolicy = .init()) -> DungeonPipeline {
        addingNamed("placeDoors") { res in
            res.dungeon = EdgeDoors.placeDoorsAndTag(res.dungeon, seed: seed, policy: policy)
        }
    }

    /// Plan locks across region graph (updates edges) and return plan.
    public func planLocks(maxLocks: Int = 2, doorBias: Int = 2) -> DungeonPipeline {
        addingNamed("planLocks") { res in
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
        addingNamed("theme") { res in
            let index = DungeonIndex(res.dungeon)
            let assign = Themer.assignThemes(dungeon: res.dungeon, index: index, seed: seed, rules: rules)
            res.themeAssignment = assign
        }
    }

    /// Plan placements for a given kind/policy (does not mutate the dungeon).
    public func place(kind: String, policy: PlacementPolicy, seed: UInt64) -> DungeonPipeline {
        addingNamed("place[\(kind)]") { res in
            let index = DungeonIndex(res.dungeon)
            let ps = Placer.plan(in: res.dungeon, index: index, seed: seed, kind: kind, policy: policy)
            if res.placements[kind] != nil {
                res.placements[kind]! += ps
            } else {
                res.placements[kind] = ps
            }
        }
    }

    // MARK: - Run

    @discardableResult
    public func run() -> DungeonPipelineResult {
        var out = DungeonPipelineResult(dungeon: base)
        var stepMetrics: [DungeonPipelineMetrics.Step] = []
        stepMetrics.reserveCapacity(steps.count)

        for (i, step) in steps.enumerated() {
            let t0 = DispatchTime.now().uptimeNanoseconds
            step(&out)
            let t1 = DispatchTime.now().uptimeNanoseconds
            let ms = Double(t1 &- t0) / 1_000_000.0
            let name = (i < names.count ? names[i] : "step[\(i)]")
            stepMetrics.append(.init(name: name, durationMS: ms))
        }

        // Totals from final dungeon
        let d = out.dungeon
        let w = d.grid.width, h = d.grid.height
        var walls = 0, floors = 0, doorsT = 0
        for t in d.grid.tiles {
            switch t {
            case .wall:  walls  += 1
            case .floor: floors += 1
            case .door:  doorsT += 1
            }
        }
        let doorH = d.edges.h.reduce(0) { $0 + ($1 == .door ? 1 : 0) }
        let doorV = d.edges.v.reduce(0) { $0 + ($1 == .door ? 1 : 0) }
        let byKind = out.placements.mapValues { $0.count }

        out.metrics = DungeonPipelineMetrics(
            steps: stepMetrics,
            totals: .init(width: w,
                          height: h,
                          tilesWall: walls,
                          tilesFloor: floors,
                          tilesDoor: doorsT,
                          doorEdgesH: doorH,
                          doorEdgesV: doorV,
                          rooms: d.rooms.count,
                          placementsByKind: byKind)
        )
        return out
    }

    // MARK: - Internals

    private func addingNamed(_ name: String, _ s: @escaping Step) -> DungeonPipeline {
        DungeonPipeline(base: base, steps: steps + [s], names: names + [name])
    }
}
