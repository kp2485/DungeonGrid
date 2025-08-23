//
//  SnapshotASCIITests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation
import Testing
@testable import DungeonGrid

// MARK: - Local helpers (self-contained)

/// String label for an Algorithm (avoids tricky enum interpolation).
fileprivate func algoName(_ a: Algorithm) -> String {
    switch a {
    case .bsp:            return "bsp"
    case .maze:           return "maze"
    case .caves:          return "caves"
    case .uniformRooms:   return "uniformRooms"
    }
}

/// Render a dungeon as ASCII (double-resolution so edges are visible).
/// Legend: '#' wall, '.' floor, '+' door edge, 'D' door tile, 'S' entrance, 'E' exit, ' ' open edge.
fileprivate func renderASCII(_ d: Dungeon) -> String {
    let W = d.grid.width, H = d.grid.height
    let AW = W * 2 + 1, AH = H * 2 + 1
    var canvas = Array(repeating: Array(repeating: Character("#"), count: AW), count: AH)

    @inline(__always) func set(_ x: Int, _ y: Int, _ ch: Character) {
        guard y >= 0, y < AH, x >= 0, x < AW else { return }
        canvas[y][x] = ch
    }

    // Cells at odd coords
    for y in 0..<H {
        for x in 0..<W {
            let ax = 2*x + 1, ay = 2*y + 1
            switch d.grid[x, y] {
            case .wall: break
            case .floor: set(ax, ay, ".")
            case .door:  set(ax, ay, "D")
            }
        }
    }

    // Horizontal edges (between row y-1 and y) at (2*x+1, 2*y)
    for y in 0...H {
        for x in 0..<W {
            let ax = 2*x + 1, ay = 2*y
            let e = d.edges[hx: x, hy: y]
            if e == .open { set(ax, ay, " ") }
            else if e == .door { set(ax, ay, "+") }
        }
    }

    // Vertical edges (between col x-1 and x) at (2*x, 2*y+1)
    for y in 0..<H {
        for x in 0...W {
            let ax = 2*x, ay = 2*y + 1
            let e = d.edges[vx: x, vy: y]
            if e == .open { set(ax, ay, " ") }
            else if e == .door { set(ax, ay, "+") }
        }
    }

    if let s = d.entrance { set(2*s.x + 1, 2*s.y + 1, "S") }
    if let t = d.exit     { set(2*t.x + 1, 2*t.y + 1, "E") }

    return canvas.map { String($0) }.joined(separator: "\n")
}

/// Print only when SHOW_ASCII=1 to keep CI quiet.
fileprivate func printASCIIIfEnabled(_ title: String, _ d: Dungeon) {
    if ProcessInfo.processInfo.environment["SHOW_ASCII"] == "1" {
        print("\n=== \(title) ===\n\(renderASCII(d))")
    }
}

// MARK: - Tests

@Suite struct SnapshotASCIITests {

    static let sizes: [(Int, Int)] = [(21, 13), (41, 25), (80, 48)]
    static let seeds: [UInt64] = [1, 2, 42]

    @Test func showcase() {
        let algos: [Algorithm] = [
            .bsp(BSPOptions()),
            .uniformRooms(UniformRoomsOptions()),
            .maze(MazeOptions()),
            .caves(CavesOptions())
        ]

        for (w, h) in Self.sizes {
            for algo in algos {
                for seed in Self.seeds {
                    let cfg = DungeonConfig(
                        width: w,
                        height: h,
                        algorithm: algo,
                        ensureConnected: true,
                        placeDoorsAndTags: true
                    )
                    let d = DungeonGrid.generate(config: cfg, seed: seed)

                    // Print (opt-in)
                    printASCIIIfEnabled("\(algoName(algo)) \(w)x\(h) seed=\(seed)", d)

                    // Light invariants (use explicit closure to avoid any macro parsing quirks)
                    #expect({ d.grid.width == w && d.grid.height == h }())
                    #expect({ d.grid.tiles.contains(.floor) }())
                }
            }
        }
    }
}
