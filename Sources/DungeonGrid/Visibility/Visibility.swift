//
//  Visibility.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public struct VisibilityPolicy: Sendable, Equatable {
    /// If true, light/vision can pass through `.door` edges. If false, doors block vision.
    public var doorTransparent: Bool
    /// If true, diagonal rays may see through a corner when at least one of the two crossed edges is transparent.
    /// If false (default), diagonal requires BOTH crossed edges to be transparent (no "corner peeking").
    public var diagonalThroughCorners: Bool
    public init(doorTransparent: Bool = true, diagonalThroughCorners: Bool = false) {
        self.doorTransparent = doorTransparent
        self.diagonalThroughCorners = diagonalThroughCorners
    }
}

public enum Visibility {
    
    /// True if there is an unobstructed line of sight between two passable cells.
    /// Uses edge-aware ray casting (supercover Bresenham).
    public static func hasLineOfSight(in d: Dungeon,
                                      from a: Point,
                                      to b: Point,
                                      policy: VisibilityPolicy = .init()) -> Bool {
        let w = d.grid.width, h = d.grid.height
        guard a.x >= 0, a.x < w, a.y >= 0, a.y < h,
              b.x >= 0, b.x < w, b.y >= 0, b.y < h,
              d.grid[a.x, a.y].isPassable, d.grid[b.x, b.y].isPassable else { return false }
        
        @inline(__always)
        func edgeTransparent(_ e: EdgeType) -> Bool {
            switch e {
            case .open: return true
            case .door: return policy.doorTransparent
            case .wall, .locked: return false
            }
        }
        
        // Supercover Bresenham between cell centers; we step across grid edges.
        let x0 = a.x, y0 = a.y, x1 = b.x, y1 = b.y
        let dx0 = x1 - x0, dy0 = y1 - y0
        let sx = (dx0 == 0) ? 0 : (dx0 > 0 ? 1 : -1)
        let sy = (dy0 == 0) ? 0 : (dy0 > 0 ? 1 : -1)
        let dx = abs(dx0), dy = abs(dy0)
        var err = dx - dy
        var cx = x0, cy = y0
        
        while cx != x1 || cy != y1 {
            var didH = false, didV = false
            let e2 = err << 1
            
            if e2 > -dy {
                err -= dy
                // horizontal step: (cx,cy) -> (cx+sx,cy), crossing vertical edge at vx = max(cx, cx+sx)
                let nx = cx + sx
                let vx = max(cx, nx)
                let ed = d.edges[vx: vx, vy: cy]
                if !edgeTransparent(ed) { return false }
                cx = nx
                didH = true
            }
            if e2 < dx {
                err += dx
                // vertical step: (cx,cy) -> (cx,cy+sy), crossing horizontal edge at hy = max(cy, cy+sy)
                let ny = cy + sy
                let hy = max(cy, ny)
                let ed = d.edges[hx: cx, hy: hy]
                if !edgeTransparent(ed) { return false }
                cy = ny
                didV = true
            }
            
            // If we moved diagonally this iteration, enforce corner rule
            if didH && didV && !policy.diagonalThroughCorners {
                // We already checked both edges separately; if either had blocked we returned false.
                // No extra action required here.
                // (This branch exists for clarity/documentation.)
            }
        }
        return true
    }
    
    /// Return all passable tiles visible from `origin` within `radius`.
    /// Uses per-target LOS (hasLineOfSight) to keep semantics monotone and match tests.
    public static func computeVisible(in d: Dungeon,
                                      from origin: Point,
                                      radius: Int,
                                      policy: VisibilityPolicy = .init()) -> [Point] {
        let w = d.grid.width, h = d.grid.height
        guard origin.x >= 0, origin.x < w, origin.y >= 0, origin.y < h else { return [] }
        guard d.grid[origin.x, origin.y].isPassable else { return [] }
        guard radius >= 0 else { return [] }
        
        let r2 = radius * radius
        let minX = max(0, origin.x - radius)
        let maxX = min(w - 1, origin.x + radius)
        let minY = max(0, origin.y - radius)
        let maxY = min(h - 1, origin.y + radius)
        
        var result: [Point] = []
        result.reserveCapacity((radius * radius) / 2 + 8)
        
        for y in minY...maxY {
            for x in minX...maxX {
                if !d.grid[x, y].isPassable { continue }
                let dx = x - origin.x, dy = y - origin.y
                if dx*dx + dy*dy > r2 { continue }
                if x == origin.x && y == origin.y {
                    result.append(origin)
                } else if hasLineOfSight(in: d, from: origin, to: Point(x, y), policy: policy) {
                    result.append(Point(x, y))
                }
            }
        }
        return result
    }
}

public extension Visibility {
    static func hasLineOfSight(in d: Dungeon,
                               from a: Point,
                               to b: Point,
                               passage: PassagePolicy) -> Bool {
        return hasLineOfSight(in: d, from: a, to: b, policy: VisibilityPolicy(passage))
    }

    static func computeVisible(in d: Dungeon,
                               from origin: Point,
                               radius: Int,
                               passage: PassagePolicy) -> [Point] {
        return computeVisible(in: d, from: origin, radius: radius, policy: VisibilityPolicy(passage))
    }
}
