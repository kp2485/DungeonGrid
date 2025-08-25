//
//  ExternalPlacement.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  Accepts outside collections of game objects (enemies, chests, items) via a
//  small protocol and places them deterministically using existing policies.
//

import Foundation

// MARK: - Footprint (extensible)
//
// For now, keep it simple: 1x1. You can extend to .rect/.mask later without
// breaking the external interface.
public enum Footprint {
    case single
    // Future:
    // case rect(width: Int, height: Int)
    // case mask([Point]) // local offsets
}

// MARK: - Minimal protocol + type-erased wrapper

/// Minimal info DungeonGrid needs to place an external object.
/// Your game types should conform to this (directly or via small adapters).
public protocol PlaceableLike {
    associatedtype ExternalID: Hashable

    /// Stable identifier that flows back in the result so callers can match placements to their objects.
    var id: ExternalID { get }

    /// Optional tag useful for analytics/visualization; can be "enemy", "npc.merchant", "chest", etc.
    var kind: String { get }

    /// Tile footprint (single tile for now).
    var footprint: Footprint { get }

    /// Placement constraints (rooms/corridors, spacing, LOS, min distance…)
    var policy: PlacementPolicy { get }

    /// Optional theme gating: allow only regions whose theme name is in this set.
    var allowedThemeNames: [String]? { get }
}

/// Type-erased wrapper so the planner can take heterogeneous collections (any mix of enemies/items).
public struct AnyPlaceable {
    public let id: AnyHashable
    public let kind: String
    public let footprint: Footprint
    public let policy: PlacementPolicy
    public let allowedThemeNames: [String]?

    public init<ID: Hashable>(id: ID, kind: String, footprint: Footprint, policy: PlacementPolicy, allowedThemeNames: [String]? = nil) {
        self.id = AnyHashable(id)
        self.kind = kind
        self.footprint = footprint
        self.policy = policy
        self.allowedThemeNames = allowedThemeNames
    }

    public init<P: PlaceableLike>(_ p: P) {
        self.id = AnyHashable(p.id)
        self.kind = p.kind
        self.footprint = p.footprint
        self.policy = p.policy
        self.allowedThemeNames = p.allowedThemeNames
    }
}

// MARK: - Result type keyed by the caller’s IDs

public struct EntityPlacement<ID: Hashable>: Equatable {
    public let id: ID
    public let position: Point
    public let region: RegionID?

    public init(id: ID, position: Point, region: RegionID?) {
        self.id = id
        self.position = position
        self.region = region
    }
}

public struct ExternalPlacementResult: Equatable {
    public let placements: [EntityPlacement<AnyHashable>]
    /// Items we couldn’t place (ran out of candidates, constraints too tight, etc.)
    public let rejects: [AnyPlaceable]

    public init(placements: [EntityPlacement<AnyHashable>], rejects: [AnyPlaceable]) {
        self.placements = placements
        self.rejects = rejects
    }

    public static func == (lhs: ExternalPlacementResult, rhs: ExternalPlacementResult) -> Bool {
        // Compare placements exactly; compare rejects by ID only (order-sensitive but deterministic).
        if lhs.placements != rhs.placements { return false }
        return lhs.rejects.map { $0.id } == rhs.rejects.map { $0.id }
    }
}

// MARK: - Planner
//
// Deterministic greedy planner that reuses the existing Placer.plan for candidate generation,
// honors spacing and occupancy, and supports theme/region gating via AnyPlaceable.allowedThemeNames.

public enum ExternalPlacer {

    /// Place externally-specified items deterministically.
    ///
    /// - Parameters:
    ///   - d: dungeon
    ///   - index: precomputed region index (labels/graph) for speed (pass `DungeonIndex(d)`)
    ///   - themes: optional theme assignment to gate by theme names (`AnyPlaceable.allowedThemeNames`)
    ///   - seed: PRNG seed for deterministic results
    ///   - items: outside objects (type-erased)
    ///
    /// - Returns: placements keyed by the caller’s IDs and a list of rejects that couldn’t be placed.
    public static func place(in d: Dungeon,
                             index: DungeonIndex,
                             themes: ThemeAssignment?,
                             seed: UInt64,
                             items: [AnyPlaceable]) -> ExternalPlacementResult
    {
        // Deterministic order: derive a stable sort key with SeedDeriver so input order doesn’t matter.
        let ordered: [AnyPlaceable] = items.sorted { a, b in
            let ka = stableSortKey(baseSeed: seed, id: a.id, kind: a.kind)
            let kb = stableSortKey(baseSeed: seed, id: b.id, kind: b.kind)
            return (ka, a.kind) < (kb, b.kind)
        }

        // Simple tile-occupancy set (index = y*w + x) to prevent collisions across entities.
        let w = d.grid.width
        @inline(__always) func idx(_ p: Point) -> Int { p.y * w + p.x }
        var occupied = Set<Int>(minimumCapacity: ordered.count * 2)

        var out: [EntityPlacement<AnyHashable>] = []
        out.reserveCapacity(ordered.count)
        var rejects: [AnyPlaceable] = []

        for item in ordered {
            // Per-item seed derived via SeedDeriver (stable and label-sensitive).
            let perItemSeed = perItemSeed(baseSeed: seed, id: item.id, kind: item.kind)

            // Candidate generation: reuse Placer.plan with the item’s policy/kind.
            var candidates = Placer.plan(in: d, seed: perItemSeed, kind: item.kind, policy: item.policy)
                .map(\.position)

            // Optional theme gating: if item specifies allowed names, filter to those regions.
            if let themes, let allowed = item.allowedThemeNames, !allowed.isEmpty {
                candidates = candidates.filter { p in
                    if let rid = Regions.regionID(at: p, labels: index.labels, width: index.width),
                       let th = themes.regionToTheme[rid] {
                        return allowed.contains(th.name)
                    }
                    return false
                }
            }

            // Occupancy filter
            if let pos = candidates.first(where: { !occupied.contains(idx($0)) }) {
                occupied.insert(idx(pos))
                let rid = Regions.regionID(at: pos, labels: index.labels, width: index.width)
                out.append(.init(id: item.id, position: pos, region: rid))
            } else {
                rejects.append(item)
            }
        }

        return ExternalPlacementResult(placements: out, rejects: rejects)
    }

    // MARK: - Seeding & sort keys (via SeedDeriver)

    /// Stable per-item seed derived from (base seed, textual ID, kind).
    private static func perItemSeed(baseSeed: UInt64, id: AnyHashable, kind: String) -> UInt64 {
        // Label captures the “namespace” for this derivation so it can’t collide with others.
        let label = "ExternalPlacer.item|\(id)|\(kind)"
        return SeedDeriver.derive(baseSeed, label)
    }

    /// Stable sort key so placement order is deterministic regardless of input ordering.
    private static func stableSortKey(baseSeed: UInt64, id: AnyHashable, kind: String) -> UInt64 {
        let label = "ExternalPlacer.sort|\(id)|\(kind)"
        return SeedDeriver.derive(baseSeed, label)
    }
}
