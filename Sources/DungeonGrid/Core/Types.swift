//
//  Types.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public struct Point: Sendable, Equatable, Hashable {
    public var x: Int
    public var y: Int
    public init(_ x: Int, _ y: Int) { self.x = x; self.y = y }
}

public enum Tile: UInt8, Sendable {
    case wall = 0
    case floor = 1
    case door  = 2

    public var isSolid: Bool { self == .wall }
    public var isPassable: Bool { self == .floor || self == .door }
}
