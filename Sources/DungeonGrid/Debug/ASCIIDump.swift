//
//  ASCIIDump.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//


import Foundation

public enum DungeonDebug {

    /// Render the dungeon as ASCII.
    /// Legend:
    ///  # wall   . floor   + door tile   S entrance   E exit
    ///  * path   o placement (by kind)
    public static func dumpASCII(_ d: Dungeon,
                                 placements: [Placement] = [],
                                 path: [Point] = [],
                                 annotateKinds: Bool = false) -> String {
        let w = d.grid.width, h = d.grid.height

        // Build a quick lookup for path and placements
        var isOnPath = Set<Int>()
        if !path.isEmpty {
            isOnPath.reserveCapacity(path.count)
            for p in path {
                if p.x >= 0 && p.x < w && p.y >= 0 && p.y < h {
                    isOnPath.insert(p.y * w + p.x)
                }
            }
        }

        var placeByCell = [Int: String]()
        if !placements.isEmpty {
            placeByCell.reserveCapacity(placements.count)
            for p in placements {
                let i = p.position.y * w + p.position.x
                placeByCell[i] = annotateKinds ? p.kind : "o"
            }
        }

        func glyph(x: Int, y: Int) -> String {
            let t = d.grid[x, y]
            let i = y * w + x

            // Entrances/exits override (draw after path so they stand out)
            if let s = d.entrance, s.x == x, s.y == y { return "S" }
            if let e = d.exit,     e.x == x, e.y == y { return "E" }

            // Path
            if isOnPath.contains(i) { return "*" }

            // Placements
            if let k = placeByCell[i] {
                return annotateKinds ? String(k.prefix(1)) : "o"
            }

            // Base terrain
            switch t {
            case .wall:  return "#"
            case .floor: return "."
            case .door:  return "+"
            }
        }

        var out = ""
        out.reserveCapacity((w + 1) * h)
        for y in 0..<h {
            for x in 0..<w {
                out += glyph(x: x, y: y)
            }
            if y + 1 < h { out += "\n" }
        }
        return out
    }
}
