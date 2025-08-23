//
//  Theme.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct Theme: Sendable, Equatable {
    public let name: String
    public let tags: [String: String]
    public init(_ name: String, tags: [String: String] = [:]) {
        self.name = name
        self.tags = tags
    }
}

/// Simple rule object; if a region matches, a theme is chosen (deterministically) from `options`.
public struct ThemeRule: Sendable {
    public enum RegionClass: Sendable, Equatable { case any, room, corridor }

    // Filters (nil = ignore)
    public var regionClass: RegionClass = .any
    public var minArea: Int? = nil
    public var maxArea: Int? = nil
    public var minDegree: Int? = nil
    public var maxDegree: Int? = nil
    public var deadEndOnly: Bool? = nil
    public var minDistanceFromEntrance: Int? = nil

    /// Candidate themes to choose from (deterministically).
    public var options: [Theme]
    /// Optional integer weights for options (parallel to `options`). If nil, equal weights.
    public var weights: [Int]? = nil

    public init(regionClass: RegionClass = .any,
                minArea: Int? = nil, maxArea: Int? = nil,
                minDegree: Int? = nil, maxDegree: Int? = nil,
                deadEndOnly: Bool? = nil,
                minDistanceFromEntrance: Int? = nil,
                options: [Theme],
                weights: [Int]? = nil) {
        self.regionClass = regionClass
        self.minArea = minArea
        self.maxArea = maxArea
        self.minDegree = minDegree
        self.maxDegree = maxDegree
        self.deadEndOnly = deadEndOnly
        self.minDistanceFromEntrance = minDistanceFromEntrance
        self.options = options
        self.weights = weights
    }
}

public struct ThemeAssignment: Sendable, Equatable {
    public let regionToTheme: [RegionID: Theme]
}