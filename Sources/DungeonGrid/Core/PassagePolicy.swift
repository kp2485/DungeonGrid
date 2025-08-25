//
//  PassagePolicy.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  A unified set of knobs for pathfinding + visibility.
//  This is additive: existing MovementPolicy / VisibilityPolicy continue to work.
//

import Foundation

public struct PassagePolicy: Sendable, Equatable {
    /// Treat doors as transparent for line-of-sight / FOV?
    public var doorsTransparentForLOS: Bool = false
    /// Allow diagonal LOS through corner-touching walls? (if your LOS supports it)
    public var diagonalThroughCorners: Bool = false
    /// Extra cost when crossing door edges in pathfinding.
    public var doorMoveCost: Int = 0
    /// If you add more edge states later, expose allowances here (locked, secret, etc.)
    public var allowLockedEdges: Bool = false

    public init(doorsTransparentForLOS: Bool = false,
                diagonalThroughCorners: Bool = false,
                doorMoveCost: Int = 0,
                allowLockedEdges: Bool = false) {
        self.doorsTransparentForLOS = doorsTransparentForLOS
        self.diagonalThroughCorners = diagonalThroughCorners
        self.doorMoveCost = doorMoveCost
        self.allowLockedEdges = allowLockedEdges
    }
}

// MARK: - Bridging helpers

public extension MovementPolicy {
    init(_ passage: PassagePolicy) {
        self.init(doorCost: passage.doorMoveCost)
    }
}

public extension VisibilityPolicy {
    init(_ passage: PassagePolicy) {
        self.init(
            doorTransparent: passage.doorsTransparentForLOS,
            diagonalThroughCorners: passage.diagonalThroughCorners
        )
    }
}
