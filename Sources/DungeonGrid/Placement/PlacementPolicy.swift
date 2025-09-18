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
    public var maxDistanceFromEntrance: Int? = nil
    public var minDistanceFromExit: Int? = nil
    public var maxDistanceFromExit: Int? = nil
    public var avoidLOSFromEntrance: Bool = false
    public var doorsTransparentForLOS: Bool = true
    public var minSpacing: Int = 0

    // Region-based constraints
    public var regionAreaMin: Int? = nil
    public var regionAreaMax: Int? = nil
    public var roomAreaMin: Int? = nil
    public var roomAreaMax: Int? = nil
    public var corridorAreaMin: Int? = nil
    public var corridorAreaMax: Int? = nil
    public var regionDegreeMin: Int? = nil
    public var regionDegreeMax: Int? = nil
    public var requireDeadEnd: Bool = false  // applies when regionClass is corridorsOnly

    // Door proximity constraints
    /// Exclude tiles within Manhattan radius of any .door edge (0/none to disable)
    public var avoidNearDoorEdgesRadius: Int = 0

    public init() {}

    // ✅ New: convenience initializer so tests can pass arguments
    public init(
        count: Int? = nil,
        density: Double? = nil,
        regionClass: RegionClass = .any,
        excludeDoorTiles: Bool = true,
        minDistanceFromEntrance: Int? = nil,
        maxDistanceFromEntrance: Int? = nil,
        minDistanceFromExit: Int? = nil,
        maxDistanceFromExit: Int? = nil,
        avoidLOSFromEntrance: Bool = false,
        doorsTransparentForLOS: Bool = true,
        minSpacing: Int = 0,
        regionAreaMin: Int? = nil,
        regionAreaMax: Int? = nil,
        roomAreaMin: Int? = nil,
        roomAreaMax: Int? = nil,
        corridorAreaMin: Int? = nil,
        corridorAreaMax: Int? = nil,
        regionDegreeMin: Int? = nil,
        regionDegreeMax: Int? = nil,
        requireDeadEnd: Bool = false,
        avoidNearDoorEdgesRadius: Int = 0
    ) {
        self.count = count
        self.density = density
        self.regionClass = regionClass
        self.excludeDoorTiles = excludeDoorTiles
        self.minDistanceFromEntrance = minDistanceFromEntrance
        self.maxDistanceFromEntrance = maxDistanceFromEntrance
        self.minDistanceFromExit = minDistanceFromExit
        self.maxDistanceFromExit = maxDistanceFromExit
        self.avoidLOSFromEntrance = avoidLOSFromEntrance
        self.doorsTransparentForLOS = doorsTransparentForLOS
        self.minSpacing = minSpacing
        self.regionAreaMin = regionAreaMin
        self.regionAreaMax = regionAreaMax
        self.roomAreaMin = roomAreaMin
        self.roomAreaMax = roomAreaMax
        self.corridorAreaMin = corridorAreaMin
        self.corridorAreaMax = corridorAreaMax
        self.regionDegreeMin = regionDegreeMin
        self.regionDegreeMax = regionDegreeMax
        self.requireDeadEnd = requireDeadEnd
        self.avoidNearDoorEdgesRadius = max(0, avoidNearDoorEdgesRadius)
    }
}
