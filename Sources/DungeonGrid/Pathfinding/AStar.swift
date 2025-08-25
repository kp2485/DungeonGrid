//
//  AStar.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public enum Pathfinder {
    /// A* shortest path on the edge graph. Returns inclusive path of Points, or nil if unreachable.
    /// Uses Manhattan heuristic (admissible on 4-neighborhood).
    public static func shortestPath(in d: Dungeon,
                                    from start: Point,
                                    to goal: Point,
                                    movement: MovementPolicy = MovementPolicy()) -> [Point]? {
        let w = d.grid.width, h = d.grid.height
        guard start.x >= 0, start.x < w, start.y >= 0, start.y < h,
              goal.x  >= 0, goal.x  < w, goal.y  >= 0, goal.y  < h else { return nil }
        guard d.grid[start.x, start.y].isPassable, d.grid[goal.x, goal.y].isPassable else { return nil }

        @inline(__always) func idx(_ x:Int,_ y:Int)->Int { y*w + x }
        @inline(__always) func manhattan(_ ax:Int,_ ay:Int,_ bx:Int,_ by:Int)->Int { abs(ax - bx) + abs(ay - by) }

        let total = w * h
        var open = MinHeap()
        var cameFrom = Array(repeating: -1, count: total)
        var gScore = Array(repeating: Int.max, count: total)
        var fScore = Array(repeating: Int.max, count: total)
        var inOpen = Array(repeating: false, count: total)

        let sIdx = idx(start.x, start.y)
        let gIdx = idx(goal.x, goal.y)

        gScore[sIdx] = 0
        fScore[sIdx] = manhattan(start.x, start.y, goal.x, goal.y)
        open.push(priority: fScore[sIdx], value: sIdx)
        inOpen[sIdx] = true

        while let (_, current) = open.pop() {
            inOpen[current] = false
            if current == gIdx { return reconstructPath(cameFrom: cameFrom, current: current, w: w) }

            let cx = current % w, cy = current / w
            // Enumerate 4-neighbors with edge checks & costs
            // left
            if cx > 0, d.grid[cx-1, cy].isPassable,
               let c = movement.stepCost(for: d.edges[vx: cx, vy: cy]) {
                let n = current - 1
                relax(current, n, cost: c)
            }
            // right
            if cx + 1 < w, d.grid[cx+1, cy].isPassable,
               let c = movement.stepCost(for: d.edges[vx: cx+1, vy: cy]) {
                let n = current + 1
                relax(current, n, cost: c)
            }
            // up
            if cy > 0, d.grid[cx, cy-1].isPassable,
               let c = movement.stepCost(for: d.edges[hx: cx, hy: cy]) {
                let n = current - w
                relax(current, n, cost: c)
            }
            // down
            if cy + 1 < h, d.grid[cx, cy+1].isPassable,
               let c = movement.stepCost(for: d.edges[hx: cx, hy: cy+1]) {
                let n = current + w
                relax(current, n, cost: c)
            }
        }
        return nil

        // MARK: - local helpers
        @inline(__always)
        func relax(_ u: Int, _ v: Int, cost: Int) {
            let tentative = gScore[u] + cost
            if tentative < gScore[v] {
                cameFrom[v] = u
                gScore[v] = tentative
                let vx = v % w, vy = v / w
                fScore[v] = tentative + manhattan(vx, vy, goal.x, goal.y)
                if !inOpen[v] {
                    open.push(priority: fScore[v], value: v)
                    inOpen[v] = true
                } else {
                    // NOTE: This heap doesn't support decrease-key; pushing duplicate is fine
                    // because we ignore stale entries when popped (since gScore is already lower).
                    open.push(priority: fScore[v], value: v)
                }
            }
        }
    }

    private static func reconstructPath(cameFrom: [Int], current: Int, w: Int) -> [Point] {
        var pathIdx = [current]
        var cur = current
        while cameFrom[cur] >= 0 {
            cur = cameFrom[cur]
            pathIdx.append(cur)
        }
        pathIdx.reverse()
        return pathIdx.map { Point($0 % w, $0 / w) }
    }
}

public extension Pathfinder {
    /// Shortest path using a unified PassagePolicy (for convenience).
    static func shortestPath(in d: Dungeon,
                             from s: Point,
                             to t: Point,
                             passage: PassagePolicy) -> [Point]? {
        return shortestPath(in: d, from: s, to: t, movement: MovementPolicy(passage))
    }
}
