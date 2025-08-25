//
//  PathfindingFuzzTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//

import Testing
@testable import DungeonGrid

@Suite struct PathfindingFuzzTests {

    // Tiny deterministic PRNG so tests are reproducible
    struct SplitMix64 {
        var x: UInt64
        mutating func next() -> UInt64 {
            x &+= 0x9E3779B97F4A7C15
            var z = x
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            z =  z ^ (z >> 31)
            return z
        }
        mutating func int(in range: ClosedRange<Int>) -> Int {
            let span = UInt64(range.upperBound - range.lowerBound + 1)
            return range.lowerBound + Int(next() % span)
        }
    }

    @inline(__always)
    func neighbors(_ d: Dungeon, _ x: Int, _ y: Int) -> [(Int, Int)] {
        let g = d.grid, e = d.edges, w = g.width, h = g.height
        var out: [(Int, Int)] = []
        if x > 0               && g[x-1,y].isPassable && e.canStep(from: x, y, to: x-1, y) { out.append((x-1,y)) }
        if x + 1 < w           && g[x+1,y].isPassable && e.canStep(from: x, y, to: x+1, y) { out.append((x+1,y)) }
        if y > 0               && g[x,y-1].isPassable && e.canStep(from: x, y, to: x, y-1) { out.append((x,y-1)) }
        if y + 1 < h           && g[x,y+1].isPassable && e.canStep(from: x, y, to: x, y+1) { out.append((x,y+1)) }
        return out
    }

    // BFS distance & predecessor map to validate A* optimality
    func bfs(_ d: Dungeon, from s: Point, to t: Point) -> (dist: [Int], prev: [Int]) {
        let w = d.grid.width, h = d.grid.height, N = w*h
        @inline(__always) func idx(_ p: Point) -> Int { p.y*w + p.x }

        var dist = Array(repeating: -1, count: N)
        var prev = Array(repeating: -1, count: N)
        var q: [Int] = []
        var head = 0

        guard d.grid[s.x, s.y].isPassable, d.grid[t.x, t.y].isPassable else { return (dist, prev) }
        let si = idx(s); dist[si] = 0; q.append(si)

        while head < q.count {
            let cur = q[head]; head += 1
            let x = cur % w, y = cur / w
            if cur == idx(t) { break }
            for (nx, ny) in neighbors(d, x, y) {
                let ni = ny*w + nx
                if dist[ni] == -1 {
                    dist[ni] = dist[cur] + 1
                    prev[ni] = cur
                    q.append(ni)
                }
            }
        }
        return (dist, prev)
    }

    func pathFromPrev(_ prev: [Int], _ w: Int, _ s: Point, _ t: Point) -> [Point] {
        @inline(__always) func idx(_ p: Point) -> Int { p.y*w + p.x }
        var out: [Point] = []
        var cur = idx(t)
        if prev[cur] == -1 { return [] }
        while cur != -1 {
            let x = cur % w, y = cur / w
            out.append(Point(x, y))
            if cur == idx(s) { break }
            cur = prev[cur]
        }
        return out.reversed()
    }

    // Try a bunch of passable pairs and compare A* to BFS
    @Test("A* matches BFS distance and respects edges")
    func compareToBFS() {
        let cfgs: [DungeonConfig] = [
            .init(width: 41, height: 25, algorithm: .bsp(BSPOptions()),         ensureConnected: true, placeDoorsAndTags: true),
            .init(width: 41, height: 25, algorithm: .maze(MazeOptions()),        ensureConnected: true, placeDoorsAndTags: true),
        ]
        let seeds: [UInt64] = [5, 17, 29] // small set to keep runtime light

        for cfg in cfgs {
            for s in seeds {
                let d = DungeonGrid.generate(config: cfg, seed: s)
                var rng = SplitMix64(x: s ^ 0xC0FFEE_BEEF)

                // Collect some passable points
                var pts: [Point] = []
                for _ in 0..<500 {
                    let x = rng.int(in: 0...(d.grid.width-1))
                    let y = rng.int(in: 0...(d.grid.height-1))
                    if d.grid[x,y].isPassable { pts.append(Point(x,y)) }
                    if pts.count >= 60 { break }
                }
                if pts.count < 2 { continue }

                // Check ~20 random pairs
                for _ in 0..<20 {
                    let a = pts[rng.int(in: 0...(pts.count-1))]
                    let b = pts[rng.int(in: 0...(pts.count-1))]
                    if a == b { continue }

                    // BFS truth
                    let (dist, prev) = bfs(d, from: a, to: b)
                    let w = d.grid.width
                    let bfsi = dist[b.y*w + b.x]

                    // A* under default MovementPolicy (no diagonals)
                    let path = Pathfinder.shortestPath(in: d, from: a, to: b, movement: .init())

                    if bfsi < 0 {
                        // unreachable → A* should also fail
                        #expect(expectOrDump(path == nil,
                                             "A* found a path where BFS says unreachable (from \(a) to \(b))",
                                             dungeon: d))
                    } else {
                        // reachable → A* should return path of the same length
                        #expect(expectOrDump(path != nil,
                                             "A* failed to find a path (BFS says reachable) (from \(a) to \(b))",
                                             dungeon: d))
                        if let p = path {
                            // step validity & length optimality
                            var ok = true
                            for i in 1..<p.count {
                                let dx = abs(p[i].x - p[i-1].x), dy = abs(p[i].y - p[i-1].y)
                                if dx + dy != 1 { ok = false; break }
                                if !d.grid[p[i].x, p[i].y].isPassable { ok = false; break }
                            }
                            #expect(expectOrDump(ok,
                                                 "A* path contains invalid steps or non-passable tiles (from \(a) to \(b))",
                                                 dungeon: d,
                                                 path: p))

                            let bfsPath = pathFromPrev(prev, w, a, b)
                            #expect(expectOrDump(p.count == bfsPath.count,
                                                 "A* path length \(p.count) != BFS length \(bfsPath.count) (from \(a) to \(b))",
                                                 dungeon: d,
                                                 path: p))
                        }
                    }
                }
            }
        }
    }
}
