//
//  AlwaysShowMapsTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation
import Testing
@testable import DungeonGrid

// ===== Local ASCII renderer (cells + edges, always prints)

fileprivate func algoName(_ a: Algorithm) -> String {
    switch a {
    case .bsp: return "bsp"
    case .maze: return "maze"
    case .caves: return "caves"
    case .uniformRooms: return "uniformRooms"
    }
}

fileprivate func hChar(_ e: EdgeType) -> Character {
    switch e {
    case .wall:   return "-"   // horizontal wall
    case .open:   return "."   // horizontal open edge
    case .door:   return "="   // horizontal door
    case .locked: return "x"   // horizontal locked
    }
}

fileprivate func vChar(_ e: EdgeType) -> Character {
    switch e {
    case .wall:   return "|"   // vertical wall
    case .open:   return ":"   // vertical open edge
    case .door:   return "!"   // vertical door
    case .locked: return "x"   // vertical locked
    }
}

/// Double-resolution render so edges are visible.
/// Cells at odd coords; edges on seams; corners are '+'.
/// Cells: '#' wall, '.' floor, 'D' door tile, 'S'/'E' entrance/exit
/// H-edges: '-' wall, '.' open, '=' door, 'x' locked
/// V-edges: '|' wall, ':' open, '!' door, 'x' locked
fileprivate func renderEdgesASCII(_ d: Dungeon) -> String {
    let W = d.grid.width, H = d.grid.height
    let AW = W * 2 + 1, AH = H * 2 + 1
    var canvas = Array(repeating: Array(repeating: Character(" "), count: AW), count: AH)

    @inline(__always) func set(_ x: Int, _ y: Int, _ ch: Character) {
        guard x >= 0, x < AW, y >= 0, y < AH else { return }
        canvas[y][x] = ch
    }

    // Corner markers
    for y in stride(from: 0, to: AH, by: 2) {
        for x in stride(from: 0, to: AW, by: 2) { set(x, y, "+") }
    }
    // Horizontal edges (between row y-1 and y) at (2*x+1, 2*y)
    for y in 0...H {
        for x in 0..<W {
            set(2*x + 1, 2*y, hChar(d.edges[hx: x, hy: y]))
        }
    }
    // Vertical edges (between col x-1 and x) at (2*x, 2*y+1)
    for y in 0..<H {
        for x in 0...W {
            set(2*x, 2*y + 1, vChar(d.edges[vx: x, vy: y]))
        }
    }
    // Cells at odd coords
    for y in 0..<H {
        for x in 0..<W {
            let ax = 2*x + 1, ay = 2*y + 1
            switch d.grid[x, y] {
            case .wall:  set(ax, ay, "#")
            case .floor: set(ax, ay, ".")
            case .door:  set(ax, ay, "D")
            }
        }
    }
    // Entrance/Exit
    if let s = d.entrance { set(2*s.x + 1, 2*s.y + 1, "S") }
    if let t = d.exit     { set(2*t.x + 1, 2*t.y + 1, "E") }

    return canvas.map { String($0) }.joined(separator: "\n")
}

// ===== Always-print tests (kept small to avoid overwhelming logs)

@Suite struct AlwaysShowMapsTests {

    // Keep the set small so logs stay readable; tweak as you wish.
    static let cases: [(Algorithm, Int, Int, UInt64)] = [
        (.bsp(BSPOptions()),                   41, 25, 42),
        (.uniformRooms(UniformRoomsOptions()), 41, 25,  7),
        (.maze(MazeOptions()), 41, 25,  3),
        (.caves(CavesOptions()),               41, 25, 11),
    ]

    @Test func show() {
        for (algo, w, h, seed) in Self.cases {
            let cfg = DungeonConfig(
                width: w, height: h, algorithm: algo,
                ensureConnected: true, placeDoorsAndTags: true
            )
            let d = DungeonGrid.generate(config: cfg, seed: seed)
            print("\n=== \(algoName(algo)) \(w)x\(h) seed=\(seed) ===")
            print(renderEdgesASCII(d))

            // Light invariants to keep the test meaningful
            #expect(d.grid.width == w && d.grid.height == h)
            #expect(d.grid.tiles.contains(.floor))
        }
    }
}
