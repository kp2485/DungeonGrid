//
//  LocksPPMRenderer.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  Minimal PPM renderer that overlays locked edges on top of a simple grid.
//  Keeps it independent from ImageRenderer so you can use it in tests, tools, or debug code.
//

import Foundation

public enum LocksPPMRenderer {

    public struct Options: Sendable {
        public var scale: Int = 4              // Pixels per tile
        public var wall: (UInt8,UInt8,UInt8)  = (30,30,35)
        public var floor: (UInt8,UInt8,UInt8) = (200,200,205)
        public var door: (UInt8,UInt8,UInt8)  = (220,180,60)
        public var locked: (UInt8,UInt8,UInt8) = (220,50,50)
        public var entrance: (UInt8,UInt8,UInt8) = (60,200,100)
        public var exit: (UInt8,UInt8,UInt8) = (200,60,200)

        public init() {}
    }

    /// Render a PPM (binary P6) image with locked edge overlays.
    public static func render(_ d: Dungeon, options: Options = .init()) -> Data {
        let w = d.grid.width, h = d.grid.height
        precondition(w > 0 && h > 0)
        let S = max(1, options.scale)

        // Pixel dimensions
        let W = w * S
        let H = h * S

        // Raw RGB buffer
        var buf = [UInt8](repeating: 0, count: W * H * 3)

        @inline(__always) func put(_ x: Int, _ y: Int, _ c: (UInt8,UInt8,UInt8)) {
            guard x >= 0, x < W, y >= 0, y < H else { return }
            let i = (y * W + x) * 3
            buf[i+0] = c.0; buf[i+1] = c.1; buf[i+2] = c.2
        }
        @inline(__always) func fillRect(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ c: (UInt8,UInt8,UInt8)) {
            let xx0 = max(0, min(x0, x1)), xx1 = min(W-1, max(x0, x1))
            let yy0 = max(0, min(y0, y1)), yy1 = min(H-1, max(y0, y1))
            var y = yy0
            while y <= yy1 {
                var x = xx0
                while x <= xx1 {
                    let i = (y * W + x) * 3
                    buf[i+0] = c.0; buf[i+1] = c.1; buf[i+2] = c.2
                    x += 1
                }
                y += 1
            }
        }

        // 1) Base grid
        for y in 0..<h {
            for x in 0..<w {
                let color: (UInt8,UInt8,UInt8)
                switch d.grid[x, y] {
                case .wall:  color = options.wall
                case .floor: color = options.floor
                case .door:  color = options.door
                }
                fillRect(x*S, y*S, (x+1)*S - 1, (y+1)*S - 1, color)
            }
        }

        // 2) Overlay locked edges
        // Thickness: scale/4 (at least 1)
        let T = max(1, S / 4)

        // Horizontal edges: (hx: x, hy: y) separates row y-1 and y, for y in 1..<h, x in 0..<w
        for x in 0..<w {
            for y in 1..<h where d.edges[hx: x, hy: y] == .locked {
                let py = y * S
                fillRect(x*S, py - T/2, (x+1)*S - 1, py + (T-1)/2, options.locked)
            }
        }

        // Vertical edges: (vx: x, vy: y) separates col x-1 and x, for x in 1..<w, y in 0..<h
        for y in 0..<h {
            for x in 1..<w where d.edges[vx: x, vy: y] == .locked {
                let px = x * S
                fillRect(px - T/2, y*S, px + (T-1)/2, (y+1)*S - 1, options.locked)
            }
        }

        // 3) Entrance/Exit markers as squares (if present)
        if let s = d.entrance {
            fillRect(s.x*S, s.y*S, (s.x+1)*S - 1, (s.y+1)*S - 1, options.entrance)
        }
        if let e = d.exit {
            fillRect(e.x*S, e.y*S, (e.x+1)*S - 1, (e.y+1)*S - 1, options.exit)
        }

        // 4) Encode PPM
        var data = Data()
        data.append("P6\n\(W) \(H)\n255\n".data(using: .ascii)!)
        data.append(buf, count: buf.count)
        return data
    }
}
