//
//  DungeonLint.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  Lightweight invariants checker for dungeons.
//  Returns human-readable issues instead of throwing.
//

import Foundation

public enum DungeonLint {
    public struct Issue: Sendable, Equatable, CustomStringConvertible {
        public let message: String
        public init(_ message: String) { self.message = message }
        public var description: String { message }
    }

    /// Run a suite of invariant checks and return any issues found.
    /// Add or remove checks here as the engine evolves.
    @discardableResult
    public static func check(_ d: Dungeon) -> [Issue] {
        var issues: [Issue] = []
        issues.reserveCapacity(8)

        // 1) Entrance/exit presence if doors+tags are expected (heuristic).
        // If either is present, both should be present.
        if (d.entrance == nil) != (d.exit == nil) {
            issues.append(.init("Entrance/exit mismatch: entrance=\(String(describing: d.entrance)), exit=\(String(describing: d.exit))"))
        }

        // 2) If both are present, they must be on passable tiles.
        if let s = d.entrance {
            if !d.grid[s.x, s.y].isPassable {
                issues.append(.init("Entrance at (\(s.x),\(s.y)) is not on a passable tile"))
            }
        }
        if let t = d.exit {
            if !d.grid[t.x, t.y].isPassable {
                issues.append(.init("Exit at (\(t.x),\(t.y)) is not on a passable tile"))
            }
        }

        // 3) If both are present, there should be a connected path under edge constraints.
        if let s = d.entrance, let t = d.exit {
            if !isReachable(in: d, from: s, to: t) {
                issues.append(.init("Entrance and exit are not connected via passable cells and open/door edges"))
            }
        }

        // 4) Door rasterization invariants (edges-as-truth):
        // 4a) Every door tile should touch at least one door edge.
        for p in d.doors {
            if !touchesDoorEdge(d, x: p.x, y: p.y) {
                issues.append(.init("Door tile at (\(p.x),\(p.y)) does not touch a .door edge"))
            }
        }

        // 4b) Every door edge should have at least one adjacent door tile.
        // Vertical door edges: x in 1...w-1, y in 0...h-1
        for y in 0..<d.grid.height {
            for x in 1..<d.grid.width where d.edges[vx: x, vy: y] == .door {
                if !hasDoorTileAdjacentToDoorEdge(d, vertical: true, a: x, b: y) {
                    issues.append(.init("Vertical door edge (vx:\(x),vy:\(y)) has no adjacent door tile"))
                }
            }
        }
        // Horizontal door edges: y in 1...h-1, x in 0...w-1
        for x in 0..<d.grid.width {
            for y in 1..<d.grid.height where d.edges[hx: x, hy: y] == .door {
                if !hasDoorTileAdjacentToDoorEdge(d, vertical: false, a: x, b: y) {
                    issues.append(.init("Horizontal door edge (hx:\(x),hy:\(y)) has no adjacent door tile"))
                }
            }
        }

        // 5) Optional: doors should not be on the outer border cells.
        for p in d.doors {
            if p.x == 0 || p.y == 0 || p.x == d.grid.width - 1 || p.y == d.grid.height - 1 {
                issues.append(.init("Door tile at border (\(p.x),\(p.y))"))
            }
        }

        return issues
    }

    // MARK: - Helpers

    /// Simple BFS respecting passability + edge gates.
    private static func isReachable(in d: Dungeon, from s: Point, to t: Point) -> Bool {
        let w = d.grid.width, h = d.grid.height, total = w * h
        guard d.grid[s.x, s.y].isPassable, d.grid[t.x, t.y].isPassable else { return false }
        @inline(__always) func idx(_ x: Int, _ y: Int) -> Int { y * w + x }

        var seen = Array(repeating: false, count: total)
        var q: [Int] = []; q.reserveCapacity(total / 8)
        var head = 0
        let si = idx(s.x, s.y); q.append(si); seen[si] = true

        while head < q.count {
            let cur = q[head]; head += 1
            if cur == idx(t.x, t.y) { return true }
            let x = cur % w, y = cur / w

            forEachNeighbor(x, y, w, h, d.grid, d.edges) { nx, ny in
                let ni = idx(nx, ny)
                if !seen[ni] { seen[ni] = true; q.append(ni) }
            }
        }
        return false
    }

    /// Does a door-edge touch tile (x,y)?
    private static func touchesDoorEdge(_ d: Dungeon, x: Int, y: Int) -> Bool {
        let w = d.grid.width, h = d.grid.height
        if x > 0,   d.edges[vx: x,   vy: y] == .door { return true }
        if x + 1 <= w, d.edges[vx: x+1, vy: y] == .door { return true }
        if y > 0,   d.edges[hx: x, hy: y] == .door { return true }
        if y + 1 <= h, d.edges[hx: x, hy: y+1] == .door { return true }
        return false
    }

    /// For a door edge at (a,b), check if at least one adjacent tile is `.door`.
    private static func hasDoorTileAdjacentToDoorEdge(_ d: Dungeon, vertical: Bool, a: Int, b: Int) -> Bool {
        let g = d.grid
        if vertical {
            let x = a, y = b
            if x > 0, g[x-1, y] == .door { return true }
            if x < g.width, g[x, y] == .door { return true }
            return false
        } else {
            let x = a, y = b
            if y > 0, g[x, y-1] == .door { return true }
            if y < g.height, g[x, y] == .door { return true }
            return false
        }
    }
}
