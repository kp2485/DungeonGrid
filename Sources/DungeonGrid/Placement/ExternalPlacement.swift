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
