//
//  Neighbors.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

/// Iterate 4-neighbors (von Neumann) that are passable per tiles AND edge grid.
@inline(__always)
public func forEachNeighbor(
    _ x: Int, _ y: Int,
    _ w: Int, _ h: Int,
    _ grid: Grid,
    _ edges: EdgeGrid,
    _ body: (_ nx: Int, _ ny: Int) -> Void
) {
    // left
    if x > 0, grid[x-1, y].isPassable, edges.canStep(from: x, y, to: x-1, y) {
        _ = { body(x-1, y) }()
    }
    // right
    if x + 1 < w, grid[x+1, y].isPassable, edges.canStep(from: x, y, to: x+1, y) {
        _ = { body(x+1, y) }()
    }
    // up
    if y > 0, grid[x, y-1].isPassable, edges.canStep(from: x, y, to: x, y-1) {
        _ = { body(x, y-1) }()
    }
    // down
    if y + 1 < h, grid[x, y+1].isPassable, edges.canStep(from: x, y, to: x, y+1) {
        _ = { body(x, y+1) }()
    }
}
