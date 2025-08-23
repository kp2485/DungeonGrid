//
//  Placement.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct Placement: Sendable, Equatable {
    public let kind: String
    public let position: Point
    /// Optional region id for the placement (room or corridor component).
    public let region: RegionID?
    public init(kind: String, position: Point, region: RegionID?) {
        self.kind = kind
        self.position = position
        self.region = region
    }
}