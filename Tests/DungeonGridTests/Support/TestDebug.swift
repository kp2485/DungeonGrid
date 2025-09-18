//
//  TestDebug.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  Helper to auto-dump ASCII.
//

import Foundation
import Testing
@testable import DungeonGrid

/// Lightweight debug helpers available to tests.
/// Intentionally **no** `expectOrDump` here anymore.
enum TestDebug {

    /// ASCII render of the dungeon grid for quick visual debugging.
    /// '#' = wall, '.' = floor, '+' = door (if your `Tile` enum has it), '?' = other.
    static func ascii(_ d: Dungeon) -> String {
        var s = ""
        s.reserveCapacity((d.grid.width + 1) * d.grid.height)

        for y in 0..<d.grid.height {
            for x in 0..<d.grid.width {
                let t = d.grid[x, y]   // unlabeled subscript (x, y)
                switch t {
                case .wall:  s.append("#")
                case .floor: s.append(".")
                case .door:  s.append("+")
                default:     s.append("?")
                }
            }
            s.append("\n")
        }
        return s
    }

    /// Print an ASCII map to the test log.
    static func print(_ d: Dungeon, file: StaticString = #filePath, line: UInt = #line) {
        Swift.print(ascii(d))
    }

    /// If you still want a one-liner that asserts and dumps the map,
    /// call this explicitly from tests (kept generic and descriptive).
    static func assertTrueOrDump(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String = "",
        dungeon: Dungeon? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if !condition() {
            if let d = dungeon {
                Swift.print("---- Dungeon ASCII ----")
                Swift.print(ascii(d))
                Swift.print("-----------------------")
            }
            #expect(Bool(false), "\(message())", sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line)))
        }
    }
}
