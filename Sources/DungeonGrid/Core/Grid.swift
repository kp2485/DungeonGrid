//
//  Grid.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct Grid: Sendable {
    public let width: Int
    public let height: Int
    public var tiles: [Tile]

    public init(width: Int, height: Int, fill: Tile = .wall) {
        self.width = width
        self.height = height
        self.tiles = Array(repeating: fill, count: width * height)
    }

    @inline(__always)
    public func index(_ x: Int, _ y: Int) -> Int { y * width + x }

    public subscript(_ x: Int, _ y: Int) -> Tile {
        get {
            precondition(x >= 0 && x < width && y >= 0 && y < height, "Index out of range")
            return tiles[index(x, y)]
        }
        set {
            precondition(x >= 0 && x < width && y >= 0 && y < height, "Index out of range")
            tiles[index(x, y)] = newValue
        }
    }

    public mutating func fill(_ tile: Tile) {
        for i in tiles.indices { tiles[i] = tile }
    }
}