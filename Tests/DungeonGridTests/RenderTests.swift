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
        let d = DungeonGrid.generate(
            config: .init(width: 41, height: 25, algorithm: .bsp(BSPOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: 101
        )
        let opts = ImageRenderer.Options(cellSize: 6, edgeThickness: 1, drawOpenEdges: true, drawEdges: true, drawGrid: false)
        let (w, h, buf) = ImageRenderer.rasterize(d, options: opts)
        #expect(w == 41*6 + 1)
        #expect(h == 25*6 + 1)
        #expect(buf.count == w*h*4)
    }

    @Test("PPM data is non-empty, begins with P6 header, and includes a path overlay")
    func ppmOutput() {
        let d = DungeonGrid.generate(
            config: .init(width: 31, height: 19, algorithm: .uniformRooms(UniformRoomsOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: 202
        )

        // Theming + a few room placements (same as before)
        let g = Regions.extractGraph(d)
        let stats = RegionAnalysis.computeStats(dungeon: d, graph: g)
        let rules: [ThemeRule] = [
            ThemeRule(regionClass: .room, options: [Theme("room")]),
            ThemeRule(regionClass: .corridor, options: [Theme("corridor")])
        ]
        let themed = Themer.assignThemes(dungeon: d, graph: g, stats: stats, seed: 9, rules: rules)

        var pol = PlacementPolicy(); pol.count = 12; pol.minSpacing = 2; pol.regionClass = .roomsOnly
        let placements = Placer.plan(in: d, seed: 77, kind: "loot", policy: pol)

        // ➕ Compute entrance→exit path (edge-aware A*)
        guard let s = d.entrance, let t = d.exit else {
            #expect(Bool(false), "Expected entrance/exit to be present")
            return
        }
        let path = Pathfinder.shortestPath(in: d, from: s, to: t, movement: .init())
        #expect(path != nil, "Expected a path between entrance and exit")

        // Sanity: each step is 4-neighbor and passable
        if let p = path {
            for i in 1..<p.count {
                let a = p[i-1], b = p[i]
                #expect(abs(a.x - b.x) + abs(a.y - b.y) == 1)
                #expect(d.grid[b.x, b.y].isPassable)
            }
        }

        let pathsOverlay: [[Point]] = path != nil ? [path!] : []

        let data = ImageRenderer.ppmData(
            d,
            options: .init(cellSize: 5, edgeThickness: 1, drawOpenEdges: false, drawEdges: true, drawGrid: false),
            overlays: .init(graph: g, themes: themed, placements: placements, paths: pathsOverlay)
        )
        #expect(!data.isEmpty)
        // PPM header starts with "P6\n"
        let prefix = data.prefix(3)
        #expect(Array(prefix) == Array("P6\n".utf8))
    }
    
    @Test("Emit a PNG snapshot with path overlay to a predictable folder and print a clickable path")
    func pngAttachment() throws {
        let d = DungeonGrid.generate(
            config: .init(width: 41, height: 25, algorithm: .bsp(BSPOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: 404
        )
        let g = Regions.extractGraph(d)
        let stats = RegionAnalysis.computeStats(dungeon: d, graph: g)
        let themed = Themer.assignThemes(dungeon: d, graph: g, stats: stats, seed: 1, rules: [
            ThemeRule(regionClass: .room, options: [Theme("room")]),
            ThemeRule(regionClass: .corridor, options: [Theme("corridor")]),
        ])
        let placements = Placer.plan(in: d, seed: 99, kind: "enemy", policy: {
            var p = PlacementPolicy(); p.count = 12; p.regionClass = .corridorsOnly; return p
        }())

        // ➕ Compute path for overlay
        guard let s = d.entrance, let t = d.exit else {
            #expect(false, "Expected entrance/exit to be present")
            return
        }
        let path = Pathfinder.shortestPath(in: d, from: s, to: t, movement: .init())
        #expect(path != nil, "Expected a path between entrance and exit")
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
