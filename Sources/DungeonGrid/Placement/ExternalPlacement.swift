//
//  ExternalPlacement.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  Accepts outside collections of game objects (enemies, chests, items) via a
//  small protocol and places them deterministically using existing policies.
//  Now supports multi-tile footprints and simple group constraints.
//

import Foundation

// MARK: - Footprint (multi-tile capable)

public enum Footprint: Equatable {
    case single
    case rect(width: Int, height: Int) // top-left anchored
    case mask([Point])                 // local offsets; must include (0,0) if you want anchor filled

    /// Enumerate local offsets covered by this footprint.
    public func offsets() -> [Point] {
        switch self {
        case .single:
            return [Point(0, 0)]
        case .rect(let w, let h):
            var pts: [Point] = []
            pts.reserveCapacity(w * h)
            for y in 0..<h { for x in 0..<w { pts.append(Point(x, y)) } }
            return pts
        case .mask(let pts):
            return pts
        }
    }
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

    /// Tile footprint.
    var footprint: Footprint { get }

    /// Placement constraints (rooms/corridors, spacing, LOS, min distance…)
    var policy: PlacementPolicy { get }

    /// Optional theme gating: allow only regions whose theme name is in this set.
    var allowedThemeNames: [String]? { get }
}

/// Type-erased wrapper so the planner can take heterogeneous collections (any mix of enemies/items).
public struct AnyPlaceable: Equatable {
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

    public static func == (lhs: AnyPlaceable, rhs: AnyPlaceable) -> Bool {
        lhs.id == rhs.id && lhs.kind == rhs.kind && lhs.footprint == rhs.footprint
        && lhs.policy == rhs.policy && lhs.allowedThemeNames == rhs.allowedThemeNames
    }
}

// MARK: - Groups

/// Group-level constraints to keep some items clustered and/or themed together.
public struct PlacementGroup: Equatable {
    public let id: AnyHashable
    public let memberIDs: [AnyHashable]

    /// Manhattan distance between **anchors** of members must be ≤ this, if provided.
    public var maxAnchorDistance: Int?

    /// Manhattan distance between anchors must be ≥ this, if provided.
    public var minAnchorDistance: Int?

    /// If true, all members must land in the **same region** id.
    public var sameRegion: Bool

    /// If true, and themes are provided, all members must share the **same theme name**.
    public var sameTheme: Bool

    public init(
        id: AnyHashable,
        memberIDs: [AnyHashable],
        maxAnchorDistance: Int? = nil,
        minAnchorDistance: Int? = nil,
        sameRegion: Bool = false,
        sameTheme: Bool = false
    ) {
        self.id = id
        self.memberIDs = memberIDs
        self.maxAnchorDistance = maxAnchorDistance
        self.minAnchorDistance = minAnchorDistance
        self.sameRegion = sameRegion
        self.sameTheme = sameTheme
    }
}

// MARK: - Result type keyed by the caller’s IDs

public struct EntityPlacement<ID: Hashable>: Equatable {
    public let id: ID
    public let position: Point   // anchor (footprint’s origin)
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
        // Compare placements exactly; compare rejects by ID only (order-sensitive but deterministic in our algorithm).
        if lhs.placements != rhs.placements { return false }
        return lhs.rejects.map { $0.id } == rhs.rejects.map { $0.id }
    }
}

// MARK: - Planner
//
// Deterministic greedy planner that reuses the existing Placer.plan for candidate generation,
// honors occupancy (multi-tile), supports theme/region gating, and group constraints.

public enum ExternalPlacer {

    /// Place externally-specified items deterministically.
    ///
    /// - Parameters:
    ///   - d: dungeon
    ///   - index: precomputed region index (labels/graph) for speed (pass `DungeonIndex(d)`)
    ///   - themes: optional theme assignment to gate by theme names (`AnyPlaceable.allowedThemeNames`)
    ///   - seed: PRNG seed for deterministic results
    ///   - items: outside objects (type-erased)
    ///   - groups: optional list of group constraints; an item may belong to at most one group
    ///
    /// - Returns: placements keyed by the caller’s IDs and a list of rejects that couldn’t be placed.
    public static func place(
        in d: Dungeon,
        index: DungeonIndex,
        themes: ThemeAssignment?,
        seed: UInt64,
        items: [AnyPlaceable],
        groups: [PlacementGroup] = []
    ) -> ExternalPlacementResult {
        // Build group lookup
        var idToGroup: [AnyHashable: PlacementGroup] = [:]
        for g in groups {
            for m in g.memberIDs { idToGroup[m] = g }
        }

        // Deterministic order: derive a stable sort key with SeedDeriver so input order doesn’t matter.
        let ordered: [AnyPlaceable] = items.sorted { a, b in
            let ka = stableSortKey(baseSeed: seed, id: a.id, kind: a.kind)
            let kb = stableSortKey(baseSeed: seed, id: b.id, kind: b.kind)
            return (ka, a.kind) < (kb, b.kind)
        }

        // Occupancy over ALL tiles
        let w = d.grid.width, h = d.grid.height
        @inline(__always) func inBounds(_ p: Point) -> Bool {
            p.x >= 0 && p.y >= 0 && p.x < w && p.y < h
        }
        @inline(__always) func idx(_ p: Point) -> Int { p.y * w + p.x }
        var occupied = Set<Int>(minimumCapacity: ordered.count * 2)

        // Results and a quick lookup by id for group constraint checks
        var out: [EntityPlacement<AnyHashable>] = []
        out.reserveCapacity(ordered.count)
        var placedByID: [AnyHashable: EntityPlacement<AnyHashable>] = [:]

        var rejects: [AnyPlaceable] = []

        for item in ordered {
            // Per-item seed derived via SeedDeriver (stable and label-sensitive).
            let perItemSeed = perItemSeed(baseSeed: seed, id: item.id, kind: item.kind)

            // Candidate generation: reuse Placer.plan with the item’s policy/kind (anchor candidates).
            var anchors = Placer.plan(in: d, seed: perItemSeed, kind: item.kind, policy: item.policy)
                .map(\.position)

            // Optional theme gating for the **anchor** tile:
            if let themes, let allowed = item.allowedThemeNames, !allowed.isEmpty {
                anchors = anchors.filter { p in
                    if let rid = Regions.regionID(at: p, labels: index.labels, width: index.width),
                       let th = themes.regionToTheme[rid] {
                        return allowed.contains(th.name)
                    }
                    return false
                }
            }

            // Multi-tile filtering and occupancy check
            func footprintTiles(at anchor: Point) -> [Point]? {
                var tiles: [Point] = []
                tiles.reserveCapacity(item.footprint.offsets().count)
                for off in item.footprint.offsets() {
                    let tp = Point(anchor.x + off.x, anchor.y + off.y)
                    if !inBounds(tp) { return nil }
                    if !d.grid[tp.x, tp.y].isPassable { return nil }
                    if item.policy.excludeDoorTiles && d.grid[tp.x, tp.y] == .door { return nil }
                    tiles.append(tp)
                }
                return tiles
            }

            // For group constraints, we need the region and theme name of candidate anchor.
            @inline(__always)
            func regionAndThemeName(for anchor: Point) -> (RegionID?, String?) {
                let rid = Regions.regionID(at: anchor, labels: index.labels, width: index.width)
                let themeName = rid.flatMap { themes?.regionToTheme[$0]?.name }
                return (rid, themeName)
            }

            // Accept the first anchor that fits footprint, occupancy, and group constraints
            var placed: EntityPlacement<AnyHashable>? = nil

            // If item belongs to a group, precompute references to already-placed peers for quick checks
            let g = idToGroup[item.id]

            anchorLoop: for anchor in anchors {
                guard let tiles = footprintTiles(at: anchor) else { continue }
                // Occupancy
                var free = true
                for tp in tiles {
                    if occupied.contains(idx(tp)) { free = false; break }
                }
                if !free { continue }

                // Group constraints
                if let group = g {
                    // Collect already-placed peers in the same group
                    let peers = group.memberIDs.compactMap { placedByID[$0] }

                    // Anchor-based min/max distance checks against each peer
                    if let minD = group.minAnchorDistance {
                        for peer in peers {
                            let m = abs(peer.position.x - anchor.x) + abs(peer.position.y - anchor.y)
                            if m < minD { continue anchorLoop }
                        }
                    }
                    if let maxD = group.maxAnchorDistance {
                        for peer in peers {
                            let m = abs(peer.position.x - anchor.x) + abs(peer.position.y - anchor.y)
                            if m > maxD { continue anchorLoop }
                        }
                    }

                    // sameRegion / sameTheme checks (relative to **first placed** peer if any)
                    if let first = peers.first {
                        let (rid, themeName) = regionAndThemeName(for: anchor)
                        if group.sameRegion {
                            if rid != first.region { continue anchorLoop }
                        }
                        if group.sameTheme, let themes {
                            // Look up theme for the peer region
                            let peerTheme = first.region.flatMap { themes.regionToTheme[$0]?.name }
                            if themeName != peerTheme { continue anchorLoop }
                        }
                    }
                }

                // Passed all checks → place here
                let rid = Regions.regionID(at: anchor, labels: index.labels, width: index.width)
                let ep = EntityPlacement<AnyHashable>(id: item.id, position: anchor, region: rid)
                placed = ep
                // Occupy all tiles in the footprint
                for tp in tiles { occupied.insert(idx(tp)) }
                break
            }

            if let p = placed {
                out.append(p)
                placedByID[item.id] = p
            } else {
                rejects.append(item)
            }
        }

        return ExternalPlacementResult(placements: out, rejects: rejects)
    }

    // MARK: - Seeding & sort keys (via SeedDeriver)

    /// Stable per-item seed derived from (base seed, textual ID, kind).
    private static func perItemSeed(baseSeed: UInt64, id: AnyHashable, kind: String) -> UInt64 {
        let label = "ExternalPlacer.item|\(id)|\(kind)"
        return SeedDeriver.derive(baseSeed, label)
    }

    /// Stable sort key so placement order is deterministic regardless of input ordering.
    private static func stableSortKey(baseSeed: UInt64, id: AnyHashable, kind: String) -> UInt64 {
        let label = "ExternalPlacer.sort|\(id)|\(kind)"
        return SeedDeriver.derive(baseSeed, label)
    }
}
