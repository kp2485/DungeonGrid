//
//  UniformRoomsGenerator.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct UniformRoomsGenerator {
    public var options: UniformRoomsOptions
    public init(options: UniformRoomsOptions) { self.options = options }

    public mutating func generate(width: Int, height: Int, seed: UInt64) -> Dungeon {
        var rng = SplitMix64(seed: seed)
        var grid = Grid(width: width, height: height, fill: .wall)
        var rooms: [Room] = []
        var nextID = 0

        func intersects(_ a: Rect, _ b: Rect, sep: Int) -> Bool {
            !(a.x + a.width + sep <= b.x || b.x + b.width + sep <= a.x
              || a.y + a.height + sep <= b.y || b.y + b.height + sep <= a.y)
        }

        // 1) Scatter non-overlapping rooms
        for _ in 0..<options.attempts {
            let rw = rng.int(in: options.roomMin.w...options.roomMax.w)
            let rh = rng.int(in: options.roomMin.h...options.roomMax.h)
            let rx = rng.int(in: 1...(max(1, width  - rw - 2)))
            let ry = rng.int(in: 1...(max(1, height - rh - 2)))
            let rect = Rect(x: rx, y: ry, width: rw, height: rh)
            if rooms.allSatisfy({ !intersects($0.rect, rect, sep: options.separation) }) {
                rooms.append(Room(id: nextID, rect: rect)); nextID += 1
                for y in rect.minY...rect.maxY { for x in rect.minX...rect.maxX { grid[x, y] = .floor } }
            }
        }

        // ✅ Fallback: ensure at least one room exists
        if rooms.isEmpty {
            let rw = min(options.roomMax.w, max(options.roomMin.w, max(3, width  / 4)))
            let rh = min(options.roomMax.h, max(options.roomMin.h, max(3, height / 4)))
            let cx = rng.int(in: rw/2...(width  - rw/2 - 1))
            let cy = rng.int(in: rh/2...(height - rh/2 - 1))
            let rect = Rect(x: max(1, cx - rw/2), y: max(1, cy - rh/2), width: rw, height: rh)
            rooms.append(Room(id: nextID, rect: rect)); nextID += 1
            for y in rect.minY...rect.maxY { for x in rect.minX...rect.maxX { grid[x, y] = .floor } }
        }

        // 2) Connect room centers with simple MST (L-corridors)
        func md(_ a: Room,_ b: Room)->Int { abs(a.rect.midX - b.rect.midX) + abs(a.rect.midY - b.rect.midY) }
        if rooms.count >= 2 {
            var inTree = [0]; var left = Array(1..<rooms.count)
            while !left.isEmpty {
                var best = (from: 0, to: 0, d: Int.max)
                for f in inTree {
                    for t in left {
                        let d = md(rooms[f], rooms[t])
                        if d < best.d { best = (f, t, d) }
                    }
                }
                inTree.append(best.to); left.removeAll { $0 == best.to }

                let a = rooms[best.from].rect; let b = rooms[best.to].rect
                if rng.bool() {
                    carveH(min(a.midX, b.midX), max(a.midX, b.midX), a.midY, &grid)
                    carveV(min(a.midY, b.midY), max(a.midY, b.midY), b.midX, &grid)
                } else {
                    carveV(min(a.midY, b.midY), max(a.midY, b.midY), a.midX, &grid)
                    carveH(min(a.midX, b.midX), max(a.midX, b.midX), b.midY, &grid)
                }
            }
        }

        // 3) Keep a solid border
        for x in 0..<width { grid[x, 0] = .wall; grid[x, height-1] = .wall }
        for y in 0..<height { grid[0, y] = .wall; grid[width-1, y] = .wall }

        // Build edge layer (truth for walls/doors)
        let edges = BuildEdges.fromGrid(grid)

        return Dungeon(
            grid: grid,
            rooms: rooms,
            seed: seed,
            doors: [],
            entrance: nil,
            exit: nil,
            edges: edges
        )
    }
}
