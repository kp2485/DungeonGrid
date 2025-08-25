//
//  TestDebug.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  Helper to auto-dump ASCII (and optionally PPM) on failed expectations.
//

import Foundation
@testable import DungeonGrid

/// Use inside `#expect(expectOrDump(...))`. If the condition is false,
/// it prints an ASCII map to the test log, and (optionally) writes a PPM.
///
/// - Parameters:
///   - condition: expression to evaluate
///   - message: extra context line printed above the dump
///   - d: the dungeon to visualize
///   - path: optional tile path to highlight with '*'
///   - placements: optional placements rendered as 'o' (or first letter of kind if annotateKinds)
///   - annotateKinds: if true, placements use first letter of `kind` instead of 'o'
///   - writePPM: set true to always write a PPM in /tmp; or set env `DUNGEON_WRITE_PPM=1`
///   - ppmScale: pixels-per-tile for the PPM
/// - Returns: the evaluated condition (suitable to pass to `#expect(...)`)
@discardableResult
func expectOrDump(_ condition: @autoclosure () -> Bool,
                  _ message: String = "",
                  dungeon d: Dungeon,
                  path: [Point] = [],
                  placements: [Placement] = [],
                  annotateKinds: Bool = false,
                  writePPM: Bool = false,
                  ppmScale: Int = 4,
                  file: StaticString = #file,
                  line: UInt = #line) -> Bool {

    let ok = condition()
    if ok { return true }

    // ASCII to stdout
    if !message.isEmpty {
        print("❌ \(message)")
    }
    let ascii = DungeonDebug.dumpASCII(d, placements: placements, path: path, annotateKinds: annotateKinds)
    print(ascii)

    // Optional PPM snapshot to /tmp (opt-in)
    let envWantsPPM = ProcessInfo.processInfo.environment["DUNGEON_WRITE_PPM"] == "1"
    if writePPM || envWantsPPM {
        let data = LocksPPMRenderer.render(d, options: .init())
        let ts = Int(Date().timeIntervalSince1970)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dungeon_debug_\(ts).ppm")
        if (try? data.write(to: url)) != nil {
            print("🖼  Wrote PPM to \(url.path)")
        } else {
            print("⚠️  Failed to write PPM")
        }
    }

    // Return false so `#expect(expectOrDump(...))` fails as intended.
    return false
}
