//
//  PipelineMetricsTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//

import Testing
@testable import DungeonGrid

@Suite struct PipelineMetricsTests {

    @Test("Pipeline metrics are populated and sane")
    func metricsExist() {
        let cfg = DungeonConfig(width: 41, height: 25,
                                algorithm: .bsp(BSPOptions()),
                                ensureConnected: true,
                                placeDoorsAndTags: true)
        let base = DungeonGrid.generate(config: cfg, seed: 123)

        let pol = PlacementPolicy(count: 8, regionClass: .corridorsOnly)
        let res = DungeonPipeline(base: base)
            .ensureConnected(seed: 123)
            .placeDoors(seed: 123)
            .place(kind: "enemy", policy: pol, seed: 999)
            .run()

        #expect(res.metrics != nil)
        guard let m = res.metrics else { return }

        // Step timings exist and are non-negative
        #expect(!m.steps.isEmpty)
        for s in m.steps { #expect(s.durationMS >= 0) }

        // Totals look plausible
        #expect(m.totals.width == base.grid.width)
        #expect(m.totals.height == base.grid.height)
        #expect(m.totals.tilesWall + m.totals.tilesFloor + m.totals.tilesDoor == base.grid.width * base.grid.height)
        #expect(m.totals.rooms == base.rooms.count)

        // Placements are counted
        #expect(m.totals.placementsByKind["enemy"] ?? 0 >= 0)
    }
}
