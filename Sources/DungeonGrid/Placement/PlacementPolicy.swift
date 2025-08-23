//
//  PlacementPolicy.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


public struct PlacementPolicy: Sendable, Equatable {
    public var count: Int?
    public var density: Double?

    public enum RegionClass: Sendable, Equatable { case roomsOnly, corridorsOnly, any }
    public var regionClass: RegionClass = .any

    public var excludeDoorTiles: Bool = true
    public var minDistanceFromEntrance: Int? = nil
    public var avoidLOSFromEntrance: Bool = false
    public var doorsTransparentForLOS: Bool = true
    public var minSpacing: Int = 0

    public init() {}

    // ✅ New: convenience initializer so tests can pass arguments
    public init(
        count: Int? = nil,
        density: Double? = nil,
        regionClass: RegionClass = .any,
        excludeDoorTiles: Bool = true,
        minDistanceFromEntrance: Int? = nil,
        avoidLOSFromEntrance: Bool = false,
        doorsTransparentForLOS: Bool = true,
        minSpacing: Int = 0
    ) {
        self.count = count
        self.density = density
        self.regionClass = regionClass
        self.excludeDoorTiles = excludeDoorTiles
        self.minDistanceFromEntrance = minDistanceFromEntrance
        self.avoidLOSFromEntrance = avoidLOSFromEntrance
        self.doorsTransparentForLOS = doorsTransparentForLOS
        self.minSpacing = minSpacing
    }
}
