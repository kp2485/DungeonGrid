//
//  MazeGenerator.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct MazeGenerator {
    public var options: MazeOptions
    public init(options: MazeOptions) { self.options = options }

    public mutating func generate(width: Int, height: Int, seed: UInt64) -> Dungeon {
        var rng = SplitMix64(seed: seed)
        var grid = Grid(width: width, height: height, fill: .wall)

        // Carve a lattice of odd cells as initial nodes
        for y in stride(from: 1, to: height, by: 2) {
            for x in stride(from: 1, to: width, by: 2) { grid[x, y] = .floor }
        }

        // DFS (recursive-backtracker) over odd cells
        func neighbors(_ x: Int, _ y: Int) -> [(nx: Int, ny: Int, wx: Int, wy: Int)] {
            var r: [(Int, Int, Int, Int)] = []
            // (dx,dy) jumps two cells; (wx,wy) is the wall between them
            let dirs = [(2,0,1,0), (-2,0,-1,0), (0,2,0,1), (0,-2,0,-1)]
            for (dx, dy, wx, wy) in dirs {
                let nx = x + dx, ny = y + dy
                let wxp = x + wx, wyp = y + wy
                if nx > 0 && ny > 0 && nx < width - 1 && ny < height - 1 {
                    r.append((nx, ny, wxp, wyp))
                }
            }
            return r
        }

        // Track visited odd cells
        var visited = Array(repeating: false, count: width * height)
        @inline(__always) func mark(_ x: Int, _ y: Int) { visited[y * width + x] = true }
        @inline(__always) func seen(_ x: Int, _ y: Int) -> Bool { visited[y * width + x] }

        var stack: [(Int, Int)] = []
        let start = (x: 1, y: 1)
        stack.append(start); mark(start.x, start.y)

        while let (cx, cy) = stack.popLast() {
            var nexts = neighbors(cx, cy).filter { !seen($0.nx, $0.ny) }
            if nexts.isEmpty { continue }
            // Continue from current cell later
            stack.append((cx, cy))
            // Pick a neighbor randomly
            let pick = nexts[Int(rng.next() % UInt64(nexts.count))]
            // Knock down the wall and step
            grid[pick.wx, pick.wy] = .floor
            grid[pick.nx, pick.ny] = .floor
            mark(pick.nx, pick.ny)
            stack.append((pick.nx, pick.ny))
        }

        // Optional: add a few random breaches to introduce loops
        if options.carveLoops {
            let breaches = max(0, (width * height) / 80)
            for _ in 0..<breaches {
                // Keep away from border to avoid OOB checks
                guard width >= 5, height >= 5 else { break }
                let x = rng.int(in: 2...(width - 3))
                let y = rng.int(in: 2...(height - 3))
                guard grid[x, y] == .wall else { continue }

                // Count straight-adjacent floor neighbors explicitly (no ternaries)
                var n = 0
                if grid[x - 1, y] == .floor { n += 1 }
                if grid[x + 1, y] == .floor { n += 1 }
                if grid[x, y - 1] == .floor { n += 1 }
                if grid[x, y + 1] == .floor { n += 1 }

                // Only breach if it connects two corridors/rooms (avoids blobs)
                if n == 2 { grid[x, y] = .floor }
            }
        }

        let edges = BuildEdges.fromGrid(grid)
        return Dungeon(
            grid: grid,
            rooms: [],
            seed: seed,
            doors: [],
            entrance: nil,
            exit: nil,
            edges: edges
        )
    }
}
