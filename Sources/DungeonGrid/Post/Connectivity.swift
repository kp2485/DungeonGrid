//
//  Connectivity.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public struct ConnectivityReport: Sendable, Equatable {
    public let floorCount: Int
    public let componentCount: Int
    public let largestComponentSize: Int
}

public enum Connectivity {
    public static func report(for dungeon: Dungeon) -> ConnectivityReport {
        var seen = Bitset(count: dungeon.grid.tiles.count)
        let floors = dungeon.grid.walkableIndices()
        var componentSizes: [Int] = []

        for start in floors {
            if !seen[start] {
                let size = bfs(from: start, in: dungeon.grid, seen: &seen)
                componentSizes.append(size)
            }
        }

        let totalWalkable = floors.count
        let largest = componentSizes.max() ?? 0
        return ConnectivityReport(floorCount: totalWalkable,
                                  componentCount: componentSizes.count,
                                  largestComponentSize: largest)
    }

    public static func ensureConnected(_ dungeon: Dungeon, seed: UInt64) -> Dungeon {
        var grid = dungeon.grid
        var rng = SplitMix64(seed: seed)

        var seen = Bitset(count: grid.tiles.count)
        let floors = grid.walkableIndices()
        var components: [[Int]] = []
        for idx in floors where !seen[idx] {
            components.append(bfsCollect(from: idx, in: grid, seen: &seen))
        }

        if components.count <= 1 { return dungeon }

        let reps: [(x: Int, y: Int)] = components.map { comp in
            let rep = comp.min()!
            return (rep % grid.width, rep / grid.width)
        }

        var inTree: [Int] = [0]
        while inTree.count < reps.count {
            var best: (from: Int, to: Int, dist: Int)? = nil
            for f in inTree {
                for t in 0..<reps.count where !inTree.contains(t) {
                    let d = abs(reps[f].x - reps[t].x) + abs(reps[f].y - reps[t].y)
                    if best == nil || d < best!.dist { best = (f, t, d) }
                }
            }
            if let b = best {
                if rng.bool() {
                    carveH(min(reps[b.from].x, reps[b.to].x), max(reps[b.from].x, reps[b.to].x), reps[b.from].y, &grid)
                    carveV(min(reps[b.from].y, reps[b.to].y), max(reps[b.from].y, reps[b.to].y), reps[b.to].x, &grid)
                } else {
                    carveV(min(reps[b.from].y, reps[b.to].y), max(reps[b.from].y, reps[b.to].y), reps[b.from].x, &grid)
                    carveH(min(reps[b.from].x, reps[b.to].x), max(reps[b.from].x, reps[b.to].x), reps[b.to].y, &grid)
                }
                inTree.append(b.to)
            } else { break }
        }

        let edges = BuildEdges.fromGrid(grid) // rebuild, since we changed the grid
        return Dungeon(grid: grid, rooms: dungeon.rooms, seed: dungeon.seed,
                       doors: dungeon.doors, entrance: dungeon.entrance, exit: dungeon.exit,
                       edges: edges)
    }
}

// MARK: - Internals

fileprivate func bfs(from start: Int, in grid: Grid, seen: inout Bitset) -> Int {
    var q = [start]; seen[start] = true; var count = 0
    while let cur = q.popLast() {
        count += 1
        let (x, y) = (cur % grid.width, cur / grid.width)
        for (nx, ny) in neighbors4(x, y, grid.width, grid.height) {
            let nidx = ny * grid.width + nx
            if !seen[nidx], grid.tiles[nidx].isPassable {
                seen[nidx] = true; q.append(nidx)
            }
        }
    }
    return count
}

fileprivate func bfsCollect(from start: Int, in grid: Grid, seen: inout Bitset) -> [Int] {
    var q = [start]; seen[start] = true; var out: [Int] = []
    while let cur = q.popLast() {
        out.append(cur)
        let (x, y) = (cur % grid.width, cur / grid.width)
        for (nx, ny) in neighbors4(x, y, grid.width, grid.height) {
            let nidx = ny * grid.width + nx
            if !seen[nidx], grid.tiles[nidx].isPassable {
                seen[nidx] = true; q.append(nidx)
            }
        }
    }
    return out
}

fileprivate func neighbors4(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> [(Int, Int)] {
    var r: [(Int, Int)] = []
    if x > 0     { r.append((x - 1, y)) }
    if x + 1 < w { r.append((x + 1, y)) }
    if y > 0     { r.append((x, y - 1)) }
    if y + 1 < h { r.append((x, y + 1)) }
    return r
}

fileprivate struct Bitset {
    private var storage: [UInt64]
    private let countBits: Int
    init(count: Int) { countBits = count; storage = Array(repeating: 0, count: (count + 63) / 64) }
    subscript(index: Int) -> Bool {
        get { let w = index >> 6, b = index & 63; return ((storage[w] >> b) & 1) == 1 }
        set {
            let w = index >> 6, b = index & 63
            if newValue { storage[w] |= (1 << b) } else { storage[w] &= ~(1 << b) }
        }
    }
}

fileprivate extension Grid {
    func walkableIndices() -> [Int] { tiles.indices.filter { tiles[$0].isPassable } }
}
