//
//  Edges.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public enum EdgeType: UInt8, Sendable {
    case wall   = 0   // solid boundary: no passage
    case open   = 1   // no wall
    case door   = 2   // passable (you can add “closed/locked” later)
    case locked = 3   // example future state (treat as wall for now)
}

public struct EdgeGrid: Sendable, Equatable {
    public let width: Int     // cell grid width
    public let height: Int    // cell grid height

    // Horizontal edges: between row y and y+1, along columns x...(x+1)
    // Count = width * (height + 1)
    public var h: [EdgeType]

    // Vertical edges: between col x and x+1, along rows y...(y+1)
    // Count = (width + 1) * height
    public var v: [EdgeType]

    public init(width: Int, height: Int, fill: EdgeType = .wall) {
        self.width = width
        self.height = height
        self.h = Array(repeating: fill, count: width * (height + 1))
        self.v = Array(repeating: fill, count: (width + 1) * height)
    }

    @inline(__always) public func hIndex(x: Int, y: Int) -> Int { y * width + x }       // 0 <= y <= height
    @inline(__always) public func vIndex(x: Int, y: Int) -> Int { y * (width + 1) + x } // 0 <= x <= width

    // Get/Set a horizontal edge (between (x,y-1) and (x,y))
    public subscript(hx x: Int, hy y: Int) -> EdgeType {
        get { h[hIndex(x: x, y: y)] }
        set { h[hIndex(x: x, y: y)] = newValue }
    }

    // Get/Set a vertical edge (between (x-1,y) and (x,y))
    public subscript(vx x: Int, vy y: Int) -> EdgeType {
        get { v[vIndex(x: x, y: y)] }
        set { v[vIndex(x: x, y: y)] = newValue }
    }

    /// Can you step from A to B? (Assumes A and B are orthogonally adjacent cells)
    @inline(__always)
    public func canStep(from ax: Int, _ ay: Int, to bx: Int, _ by: Int) -> Bool {
        if ax == bx {
            // vertical move: crossing a horizontal edge at hy = max(ay, by)
            let hy = max(ay, by)
            let et = self[hx: ax, hy: hy]
            return et == .open || et == .door
        } else {
            // horizontal move: crossing a vertical edge at vx = max(ax, bx)
            let vx = max(ax, bx)
            let et = self[vx: vx, vy: ay]
            return et == .open || et == .door
        }
    }
}
