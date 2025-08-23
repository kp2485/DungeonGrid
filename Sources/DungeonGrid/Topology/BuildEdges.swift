//
//  BuildEdges.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public enum BuildEdges {
    /// Derive an edge layer from the tile grid:
    /// - Border edges become .wall
    /// - Interior edges are .open iff both adjacent cells are passable
    public static func fromGrid(_ g: Grid) -> EdgeGrid {
        var e = EdgeGrid(width: g.width, height: g.height, fill: .wall)

        // Horizontal edges (between rows y-1 and y), y in 0...height
        for y in 0...g.height {
            for x in 0..<g.width {
                if y == 0 || y == g.height {
                    e[hx: x, hy: y] = .wall
                } else {
                    let a = g[x, y-1].isPassable
                    let b = g[x, y].isPassable
                    e[hx: x, hy: y] = (a && b) ? .open : .wall
                }
            }
        }
        // Vertical edges (between cols x-1 and x), x in 0...width
        for y in 0..<g.height {
            for x in 0...g.width {
                if x == 0 || x == g.width {
                    e[vx: x, vy: y] = .wall
                } else {
                    let a = g[x-1, y].isPassable
                    let b = g[x, y].isPassable
                    e[vx: x, vy: y] = (a && b) ? .open : .wall
                }
            }
        }
        return e
    }
}