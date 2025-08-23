//
//  MovementPolicy.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

/// How to move through the dungeon for pathfinding.
public struct MovementPolicy: Sendable, Equatable {
    /// Extra cost for crossing a `.door` edge (0 = treat like open).
    public var doorCost: Int
    /// Locked edges are always impassable; if you ever add other edge states,
    /// you can expose flags here.
    public init(doorCost: Int = 0) {
        precondition(doorCost >= 0)
        self.doorCost = doorCost
    }

    @inline(__always) public func stepCost(for edge: EdgeType) -> Int? {
        switch edge {
        case .open:   return 1
        case .door:   return 1 + doorCost
        case .wall,
             .locked: return nil // impassable
        }
    }
}