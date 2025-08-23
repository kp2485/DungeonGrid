//
//  CavesOptions.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct CavesOptions: Sendable, Equatable {
    public var initialWallProbability: Double = 0.45
    public var survivalLimit: Int = 4
    public var birthLimit: Int = 5
    public var smoothSteps: Int = 5
    public var keepLargestComponentOnly: Bool = true
    public init() {}
}