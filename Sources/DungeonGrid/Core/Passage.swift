//
//  Passage.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

/// High-level passage kind mapped onto edge types.
public enum PassageKind: Sendable {
    case open, door, wall, locked
}

public extension EdgeGrid {
    @inline(__always)
    private func map(_ k: PassageKind) -> EdgeType {
        switch k {
        case .open:   return .open
        case .door:   return .door
        case .wall:   return .wall
        case .locked: return .locked
        }
    }
    
    /// Mutate a horizontal edge at (x,y) where the edge separates (x,y-1) ↔ (x,y).
    mutating func setHorizontal(x: Int, y: Int, to kind: PassageKind) {
        self[hx: x, hy: y] = map(kind)
    }
    
    /// Mutate a vertical edge at (x,y) where the edge separates (x-1,y) ↔ (x,y).
    mutating func setVertical(x: Int, y: Int, to kind: PassageKind) {
        self[vx: x, vy: y] = map(kind)
    }
}

/// Utilities to keep door tiles in sync with door edges (edges remain source of truth).
public enum DoorRasterizer {
    /// Derive `.door` tiles from `.door` edges using simple rules:
    /// - Room↔Room edges: mark both sides as `.door` (or room-side only, configurable later).
    /// - Room↔Corridor edges: mark the **room** side tile as `.door` by default.
    /// This will NOT clear preexisting door tiles; it only sets doors where appropriate.
    public static func rasterizeDoorTiles(dungeon d: Dungeon) -> Dungeon {
        var grid = d.grid
        let edges = d.edges
        let w = grid.width, h = grid.height
        @inline(__always) func idx(_ x: Int, _ y: Int) -> Int { y * w + x }
        
        // Clear any pre-existing `.door` tiles so edges are the source of truth
        for i in 0..<(w*h) {
            if grid.tiles[i] == .door { grid.tiles[i] = .floor }
        }
        
        // Label regions once (rooms + corridor components)
        let (labels, kinds, _, _) = Regions.labelCells(d)
        
        // Horizontal door edges at (hx: x, hy: y) separate (x,y-1) ↔ (x,y)
        for x in 0..<w {
            for y in 1..<h where edges[hx: x, hy: y] == .door {
                let ti = idx(x, y-1), bi = idx(x, y)
                let tRoom = (labels[ti] != nil && isRoomRegion(labels[ti]!, kinds: kinds))
                let bRoom = (labels[bi] != nil && isRoomRegion(labels[bi]!, kinds: kinds))
                if tRoom && bRoom {
                    grid[x, y-1] = .door
                    grid[x, y  ] = .door
                } else if tRoom != bRoom {
                    let (rx, ry) = tRoom ? (x, y-1) : (x, y)
                    grid[rx, ry] = .door
                }
            }
        }
        // Vertical door edges at (vx: x, vy: y) separate (x-1,y) ↔ (x,y)
        for y in 0..<h {
            for x in 1..<w where edges[vx: x, vy: y] == .door {
                let li = idx(x-1, y), ri = idx(x, y)
                let lRoom = (labels[li] != nil && isRoomRegion(labels[li]!, kinds: kinds))
                let rRoom = (labels[ri] != nil && isRoomRegion(labels[ri]!, kinds: kinds))
                if lRoom && rRoom {
                    grid[x-1, y] = .door
                    grid[x,   y] = .door
                } else if lRoom != rRoom {
                    let (rx, ry) = lRoom ? (x-1, y) : (x, y)
                    grid[rx, ry] = .door
                }
            }
        }
        
        return Dungeon(grid: grid, rooms: d.rooms, seed: d.seed,
                       doors: d.doors, entrance: d.entrance, exit: d.exit,
                       edges: edges)
    }
    
    /// Minimal check: is the region id associated with a room?
    @inline(__always)
    private static func isRoomRegion(_ rid: RegionID, kinds: [RegionID: RegionKind]) -> Bool {
        if case .room(_) = kinds[rid] { return true } else { return false }
    }
    
    /// Overload using a kinds map for exact classification.
    public static func rasterizeDoorTiles(dungeon d: Dungeon,
                                          labels: [RegionID?],
                                          kinds: [RegionID: RegionKind]) -> Dungeon {
        var grid = d.grid
        let edges = d.edges
        let w = grid.width, h = grid.height
        @inline(__always) func idx(_ x: Int, _ y: Int) -> Int { y * w + x }
        @inline(__always) func isRoom(_ rid: RegionID?) -> Bool {
            guard let rid else { return false }
            if case .room(_) = kinds[rid] { return true } else { return false }
        }
        
        // NEW: clear any pre-existing `.door` tiles so edges are the source of truth
        for i in 0..<(w*h) {
            if grid.tiles[i] == .door { grid.tiles[i] = .floor }
        }
        
        // Horizontal edges
        for x in 0..<w {
            for y in 1..<h where edges[hx: x, hy: y] == .door {
                let t = labels[idx(x, y-1)], b = labels[idx(x, y)]
                let tRoom = isRoom(t), bRoom = isRoom(b)
                if tRoom && bRoom { grid[x, y-1] = .door; grid[x, y] = .door }
                else if tRoom != bRoom { let (rx, ry) = tRoom ? (x, y-1) : (x, y); grid[rx, ry] = .door }
            }
        }
        // Vertical edges
        for y in 0..<h {
            for x in 1..<w where edges[vx: x, vy: y] == .door {
                let l = labels[idx(x-1, y)], r = labels[idx(x, y)]
                let lRoom = isRoom(l), rRoom = isRoom(r)
                if lRoom && rRoom { grid[x-1, y] = .door; grid[x, y] = .door }
                else if lRoom != rRoom { let (rx, ry) = lRoom ? (x-1, y) : (x, y); grid[rx, ry] = .door }
            }
        }
        
        return Dungeon(grid: grid, rooms: d.rooms, seed: d.seed,
                       doors: d.doors, entrance: d.entrance, exit: d.exit,
                       edges: edges)
    }
}
