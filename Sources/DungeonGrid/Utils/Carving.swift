//
//  Carving.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

@inline(__always)
internal func carveH(_ x0: Int, _ x1: Int, _ y: Int, _ grid: inout Grid) {
    guard y >= 0 && y < grid.height else { return }
    let lo = max(0, min(x0, x1))
    let hi = min(grid.width - 1, max(x0, x1))
    for x in lo...hi { grid[x, y] = .floor }
}

@inline(__always)
internal func carveV(_ y0: Int, _ y1: Int, _ x: Int, _ grid: inout Grid) {
    guard x >= 0 && x < grid.width else { return }
    let lo = max(0, min(y0, y1))
    let hi = min(grid.height - 1, max(y0, y1))
    for y in lo...hi { grid[x, y] = .floor }
}
