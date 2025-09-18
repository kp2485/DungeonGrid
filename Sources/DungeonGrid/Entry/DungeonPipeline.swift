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
    private let captureMetrics: Bool
    private let onStep: ((_ name: String, _ result: DungeonPipelineResult) -> Void)?

    public init(base: Dungeon) {
        self.base = base
        self.steps = []
        self.names = []
        self.captureMetrics = true
        self.onStep = nil
    }

    private init(base: Dungeon, steps: [Step], names: [String], captureMetrics: Bool, onStep: ((_ name: String, _ result: DungeonPipelineResult) -> Void)?) {
        self.base = base
        self.steps = steps
        self.names = names
        self.captureMetrics = captureMetrics
        self.onStep = onStep
    }

    // MARK: - Builder

    /// Return the list of step names accumulated so far.
    public var stepNames: [String] { names }

    /// Enable/disable metrics capture (durations, totals) in the result.
    public func withMetrics(_ enabled: Bool) -> DungeonPipeline {
        DungeonPipeline(base: base, steps: steps, names: names, captureMetrics: enabled, onStep: onStep)
    }

    /// Provide a callback invoked after each step with the step name and current result snapshot.
    public func onStep(_ cb: @escaping (_ name: String, _ result: DungeonPipelineResult) -> Void) -> DungeonPipeline {
        DungeonPipeline(base: base, steps: steps, names: names, captureMetrics: captureMetrics, onStep: cb)
    }

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
    
    /// Batch place multiple kinds in one step (shared DungeonIndex; deterministic).
    public func placeAll(_ requests: [PlacementRequest]) -> DungeonPipeline {
        addingNamed("placeAll[\(requests.count)]") { res in
            let index = DungeonIndex(res.dungeon)
            let dict = Placer.planMany(in: res.dungeon, index: index, requests: requests)
            for (k, ps) in dict {
                if res.placements[k] != nil { res.placements[k]! += ps } else { res.placements[k] = ps }
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
            let name = (i < names.count ? names[i] : "step[\(i)]")
            let t0 = DispatchTime.now().uptimeNanoseconds
            step(&out)
            let t1 = DispatchTime.now().uptimeNanoseconds
            if captureMetrics {
                let ms = Double(t1 &- t0) / 1_000_000.0
                stepMetrics.append(.init(name: name, durationMS: ms))
            }
            if let cb = onStep { cb(name, out) }
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

        if captureMetrics {
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
        }
        return out
    }

    // MARK: - Internals

    private func addingNamed(_ name: String, _ s: @escaping Step) -> DungeonPipeline {
        DungeonPipeline(base: base, steps: steps + [s], names: names + [name], captureMetrics: captureMetrics, onStep: onStep)
    }
}
