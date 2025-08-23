//
//  Dungeon.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct Dungeon: Sendable {
    public let grid: Grid
    public let rooms: [Room]
    public let seed: UInt64

    // Raster metadata (keep for compatibility/debug)
    public let doors: [Point]
    public let entrance: Point?
    public let exit: Point?

    // NEW: walls/doors live on edges between cells
    public let edges: EdgeGrid

    public init(grid: Grid,
                rooms: [Room],
                seed: UInt64,
                doors: [Point],
                entrance: Point?,
                exit: Point?,
                edges: EdgeGrid) {
        self.grid = grid
        self.rooms = rooms
        self.seed = seed
        self.doors = doors
        self.entrance = entrance
        self.exit = exit
        self.edges = edges
    }
}
