//
//  Rect.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct Rect: Sendable, Equatable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public var minX: Int { x }
    public var minY: Int { y }
    public var maxX: Int { x + width - 1 }
    public var maxY: Int { y + height - 1 }
    public var midX: Int { x + width / 2 }
    public var midY: Int { y + height / 2 }

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    public func contains(_ px: Int, _ py: Int) -> Bool {
        px >= minX && px <= maxX && py >= minY && py <= maxY
    }

    public func inset(dx: Int, dy: Int) -> Rect {
        Rect(x: x + dx, y: y + dy,
             width: max(0, width - 2 * dx),
             height: max(0, height - 2 * dy))
    }
}