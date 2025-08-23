//
//  CavesGenerator.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct CavesGenerator {
    public var options: CavesOptions
    public init(options: CavesOptions) { self.options = options }

    public mutating func generate(width: Int, height: Int, seed: UInt64) -> Dungeon {
        var rng = SplitMix64(seed: seed)
        var g = Grid(width: width, height: height, fill: .wall)

        for y in 1..<height-1 {
            for x in 1..<width-1 {
                let r = Double(rng.next() >> 11) / Double(1 << 53)
                g[x, y] = r < options.initialWallProbability ? .wall : .floor
            }
        }

        func countFloorNeighbors(_ x:Int,_ y:Int,_ grid: Grid) -> Int {
            var n = 0
            for dy in -1...1 {
                for dx in -1...1 where !(dx==0 && dy==0) {
                    let nx = x + dx, ny = y + dy
                    if nx < 0 || ny < 0 || nx >= width || ny >= height { n += 1; continue }
                    if grid[nx, ny] == .floor { n += 1 }
                }
            }
            return n
        }

        for _ in 0..<options.smoothSteps {
            var next = g
            for y in 1..<height-1 {
                for x in 1..<width-1 {
                    let floors = countFloorNeighbors(x, y, g)
                    if g[x, y] == .floor {
                        next[x, y] = (floors >= options.survivalLimit) ? .floor : .wall
                    } else {
                        next[x, y] = (floors >= options.birthLimit) ? .floor : .wall
                    }
                }
            }
            g = next
        }

        if options.keepLargestComponentOnly {
            var seen = Array(repeating: false, count: width * height)
            var best: [Int] = []
            for y in 1..<height-1 {
                for x in 1..<width-1 where g[x, y] == .floor {
                    let start = y * width + x
                    if seen[start] { continue }
                    var q = [start], comp: [Int] = []; seen[start] = true
                    while let cur = q.popLast() {
                        comp.append(cur)
                        let cx = cur % width, cy = cur / width
                        for (nx, ny) in [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)]
                        where nx > 0 && ny > 0 && nx < width-1 && ny < height-1 && g[nx, ny] == .floor {
                            let ni = ny * width + nx
                            if !seen[ni] { seen[ni] = true; q.append(ni) }
                        }
                    }
                    if comp.count > best.count { best = comp }
                }
            }
            var ng = Grid(width: width, height: height, fill: .wall)
            for i in best { ng.tiles[i] = .floor }
            g = ng
        }

        let edges = BuildEdges.fromGrid(g)
        return Dungeon(
            grid: g,
            rooms: [],
            seed: seed,
            doors: [],
            entrance: nil,
            exit: nil,
            edges: edges
        )
    }
}
