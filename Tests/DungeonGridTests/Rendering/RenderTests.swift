//
//  RenderTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation
import Testing
@testable import DungeonGrid

@Suite struct RenderTests {

    @Test("Rasterize returns correct pixel buffer size")
    func rasterSize() {
        guard let worldSeed = TestEnv.fuzzSeeds.first else { return }
        let d = DungeonGrid.generate(
            config: .init(width: 41, height: 25, algorithm: .bsp(BSPOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: worldSeed
        )
        let opts = ImageRenderer.Options(cellSize: 6, edgeThickness: 1, drawOpenEdges: true, drawEdges: true, drawGrid: false)
        let (w, h, buf) = ImageRenderer.rasterize(d, options: opts)
        #expect(w == 41*6 + 1)
        #expect(h == 25*6 + 1)
        #expect(buf.count == w*h*4)
    }

    @Test("PPM data is non-empty, begins with P6 header, and includes a path overlay")
    func ppmOutput() {
        guard let worldSeed = TestEnv.fuzzSeeds.first else { return }
        let d = DungeonGrid.generate(
            config: .init(width: 31, height: 19, algorithm: .uniformRooms(UniformRoomsOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: worldSeed
        )

        let index = DungeonIndex(d)
        let g = index.graph
        let stats = RegionAnalysis.computeStats(dungeon: d, graph: g)

        let rules: [ThemeRule] = [
            ThemeRule(regionClass: .room, options: [Theme("room")]),
            ThemeRule(regionClass: .corridor, options: [Theme("corridor")])
        ]
        let themed = Themer.assignThemes(dungeon: d, graph: g, stats: stats, seed: 9, rules: rules)

        var pol = PlacementPolicy(); pol.count = 12; pol.minSpacing = 2; pol.regionClass = .roomsOnly
        let placements = Placer.plan(in: d, seed: 77, kind: "loot", policy: pol)

        guard let s = d.entrance, let t = d.exit else {
            #expect(expectOrDump(false, "Expected entrance/exit to be present", dungeon: d))
            return
        }
        let path = Pathfinder.shortestPath(in: d, from: s, to: t, movement: .init())
        #expect(expectOrDump(path != nil, "Expected a path between entrance and exit", dungeon: d))

        if let p = path {
            for i in 1..<p.count {
                let a = p[i-1], b = p[i]
                #expect(expectOrDump(abs(a.x - b.x) + abs(a.y - b.y) == 1,
                                     "Non-4-neighbor step in path at index \(i)",
                                     dungeon: d,
                                     path: p))
                #expect(expectOrDump(d.grid[b.x, b.y].isPassable,
                                     "Path includes non-passable tile at \(b)",
                                     dungeon: d,
                                     path: p))
            }
        }

        let pathsOverlay: [[Point]] = path != nil ? [path!] : []

        let data = ImageRenderer.ppmData(
            d,
            options: .init(cellSize: 5, edgeThickness: 1, drawOpenEdges: false, drawEdges: true, drawGrid: false),
            overlays: .init(graph: g, themes: themed, placements: placements, paths: pathsOverlay)
        )
        #expect(expectOrDump(!data.isEmpty,
                             "PPM renderer returned empty data",
                             dungeon: d,
                             path: path ?? [],
                             placements: placements))

        let prefix = data.prefix(3)
        #expect(Array(prefix) == Array("P6\n".utf8))
    }
    
    @Test("Emit a PNG snapshot with path overlay to a predictable folder and print a clickable path")
    func pngAttachment() throws {
        guard let worldSeed = TestEnv.fuzzSeeds.first else { return }
        let d = DungeonGrid.generate(
            config: .init(width: 41, height: 25, algorithm: .bsp(BSPOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: worldSeed
        )
        let index = DungeonIndex(d)
        let g = index.graph
        let stats = RegionAnalysis.computeStats(dungeon: d, graph: g)
        let themed = Themer.assignThemes(dungeon: d, graph: g, stats: stats, seed: 1, rules: [
            ThemeRule(regionClass: .room, options: [Theme("room")]),
            ThemeRule(regionClass: .corridor, options: [Theme("corridor")]),
        ])
        let placements = Placer.plan(in: d, seed: 99, kind: "enemy", policy: {
            var p = PlacementPolicy(); p.count = 12; p.regionClass = .corridorsOnly; return p
        }())

        guard let s = d.entrance, let t = d.exit else {
            #expect(expectOrDump(false, "Expected entrance/exit to be present", dungeon: d))
            return
        }
        let path = Pathfinder.shortestPath(in: d, from: s, to: t, movement: .init())
        #expect(expectOrDump(path != nil, "Expected a path between entrance and exit", dungeon: d))
        let pathsOverlay: [[Point]] = path != nil ? [path!] : []

        let name = "DungeonGrid-\(d.grid.width)x\(d.grid.height)-seed\(d.seed)-path.png"

        if let png = ImageRenderer.pngData(
            d,
            options: .init(cellSize: 6, edgeThickness: 1, drawOpenEdges: false, drawEdges: true, drawGrid: false),
            overlays: .init(graph: g, themes: themed, placements: placements, paths: pathsOverlay)
        ) {
            _ = writePNGSnapshot(png, name: name)
        } else {
            let ppm = ImageRenderer.ppmData(
                d,
                options: .init(cellSize: 6, edgeThickness: 1, drawOpenEdges: false, drawEdges: true, drawGrid: false),
                overlays: .init(graph: g, themes: themed, placements: placements, paths: pathsOverlay)
            )
            _ = writePPMSnapshot(ppm, name: name.replacingOccurrences(of: ".png", with: ".ppm"))
            print("ℹ️ PNG not available (CoreGraphics/ImageIO missing). Wrote PPM instead.")
        }
    }
}
