//
//  RegionGraph.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public struct RegionID: Hashable, Sendable { public let raw: Int }

public enum RegionKind: Sendable, Equatable {
    case room(Int)      // matches Room.id
    case corridor(Int)  // corridor component index (0,1,2,…)
}

public struct RegionNode: Sendable {
    public let id: RegionID
    public let kind: RegionKind
    public let tileCount: Int
    public let bbox: Rect
    public let center: Point
}

public struct RegionEdge: Sendable, Hashable {
    public let a: RegionID
    public let b: RegionID
    /// Number of passable boundary edges that are `.open`
    public let openCount: Int
    /// Number of passable boundary edges that are `.door`
    public let doorCount: Int

    @inline(__always)
    public func weight(doorBias: Int = 0) -> Int {
        // Simple default: each open edge = 1, each door edge = 1 + doorBias
        openCount + (1 + max(0, doorBias)) * doorCount
    }
}

public struct RegionGraph: Sendable {
    public let nodes: [RegionID: RegionNode]
    public let edges: [RegionEdge]
    /// Convenience: adjacency list (undirected)
    public let adjacency: [RegionID: [RegionID]]

    public func neighbors(of id: RegionID) -> [RegionID] { adjacency[id] ?? [] }
}
