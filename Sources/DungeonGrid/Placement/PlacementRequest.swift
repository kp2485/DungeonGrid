//
//  PlacementRequest.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//

public struct PlacementRequest: Sendable, Equatable {
    public let kind: String
    public let policy: PlacementPolicy
    public let seed: UInt64

    public init(kind: String, policy: PlacementPolicy, seed: UInt64) {
        self.kind = kind
        self.policy = policy
        self.seed = seed
    }
}
