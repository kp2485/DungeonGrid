//
//  DungeonIndex.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public final class DungeonIndex: @unchecked Sendable {
    public let dungeon: Dungeon

    // Lazily-computed caches
    private var _labels: [RegionID?]? = nil
    private var _kinds: [RegionID: RegionKind]? = nil
    private var _width: Int = 0
    private var _height: Int = 0

    private var _graph: RegionGraph? = nil
    private var _stats: RegionStats? = nil

    public init(_ dungeon: Dungeon) {
        self.dungeon = dungeon
    }

    // MARK: Region labels & kinds

    public var labels: [RegionID?] {
        if let l = _labels { return l }
        let (l, k, w, h) = Regions.labelCells(dungeon)
        _labels = l
        _kinds = k
        _width = w
        _height = h
        return l
    }

    public var kinds: [RegionID: RegionKind] {
        if let k = _kinds { return k }
        let (l, k, w, h) = Regions.labelCells(dungeon)
        _labels = l
        _kinds = k
        _width = w
        _height = h
        return k
    }

    public var width: Int {
        if _width == 0 { _ = labels }
        return _width
    }

    public var height: Int {
        if _height == 0 { _ = labels }
        return _height
    }

    // MARK: Region graph

    public var graph: RegionGraph {
        if let g = _graph { return g }
        let g = Regions.extractGraph(dungeon)
        _graph = g
        return g
    }

    // MARK: Region stats

    public var stats: RegionStats {
        if let s = _stats { return s }
        // Note: depends on graph; calling graph builds/caches it.
        let s = RegionAnalysis.computeStats(dungeon: dungeon, graph: graph)
        _stats = s
        return s
    }
}

// MARK: - Convenience wrappers that reuse the cache

public extension Themer {
    /// Use cached graph + stats from DungeonIndex; seed precedes rules to match base API.
    static func assignThemes(dungeon d: Dungeon,
                             index: DungeonIndex,
                             seed: UInt64,
                             rules: [ThemeRule]) -> ThemeAssignment {
        assignThemes(dungeon: d,
                     graph: index.graph,
                     stats: index.stats,
                     seed: seed,
                     rules: rules)
    }
}

public extension RegionRouting {
    static func route(
        _ index: DungeonIndex,
        from: RegionID,
        to: RegionID,
        doorBias: Int = 0
    ) -> [RegionID]? {
        route(index.graph, from: from, to: to, doorBias: doorBias)
    }

    static func routePoints(
        _ d: Dungeon,
        index: DungeonIndex,
        from: Point,
        to: Point,
        doorBias: Int = 0
    ) -> [RegionID]? {
        let labels = index.labels
        let w = index.width
        guard
            let rs = Regions.regionID(at: from, labels: labels, width: w),
            let rt = Regions.regionID(at: to,   labels: labels, width: w)
        else { return nil }
        return route(index.graph, from: rs, to: rt, doorBias: doorBias)
    }
}
