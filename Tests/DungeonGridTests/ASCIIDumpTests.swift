//
//  ASCIIDumpTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//

import Testing
@testable import DungeonGrid

@Suite struct ASCIIDumpTests {

    @Test("ASCII dump produces the right dimensions and marks S/E")
    func asciiBasic() {
        let cfg = DungeonConfig(width: 31, height: 19,
                                algorithm: .bsp(BSPOptions()),
                                ensureConnected: true,
                                placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 1234)

        let s = DungeonDebug.dumpASCII(d)
        let lines = s.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == d.grid.height)
        #expect(lines.first?.count == d.grid.width)

        // If entrance/exit are present, they should appear in the ASCII map
        if let _ = d.entrance { #expect(s.contains("S")) }
        if let _ = d.exit     { #expect(s.contains("E")) }
    }

    @Test("ASCII dump can render paths and placements")
    func asciiWithOverlays() {
        let cfg = DungeonConfig(width: 41, height: 25,
                                algorithm: .maze(MazeOptions()),
                                ensureConnected: true,
                                placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 7)

        // Path from S to E (if both present)
        var path: [Point] = []
        if let s = d.entrance, let e = d.exit, let p = Pathfinder.shortestPath(in: d, from: s, to: e, movement: .init()) {
            path = p
        }

        var pol = PlacementPolicy(); pol.count = 5; pol.regionClass = .roomsOnly
        let ps = Placer.plan(in: d, seed: 99, kind: "enemy", policy: pol)

        let s1 = DungeonDebug.dumpASCII(d, placements: ps, path: path)
        #expect(!s1.isEmpty)
        // If a path exists, '*' should appear
        if !path.isEmpty { #expect(s1.contains("*")) }
        // Placements marked as 'o' should appear if any placements exist
        if !ps.isEmpty { #expect(s1.contains("o")) }
    }
}
