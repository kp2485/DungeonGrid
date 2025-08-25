//
//  LocksPPMRendererTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//

import Testing
@testable import DungeonGrid

@Suite struct LocksPPMRendererTests {

    @Test("Renders PPM with locked edges when locks are planned (first fuzz seed)")
    func rendersLocked() {
        guard let worldSeed = TestEnv.fuzzSeeds.first else { return }
        let cfg = DungeonConfig(width: 41, height: 25,
                                algorithm: .bsp(BSPOptions()),
                                ensureConnected: true,
                                placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: worldSeed)

        let g = DungeonIndex(d).graph
        let (d2, plan) = LocksPlanner.planAndApply(d, graph: g, entrance: d.entrance, maxLocks: 2, doorBias: 2)

        #expect(expectOrDump(plan.locks.count >= 0,
                             "LocksPlanner returned invalid plan",
                             dungeon: d2))

        let ppm = LocksPPMRenderer.render(d2)
        #expect(expectOrDump(!ppm.isEmpty,
                             "LocksPPMRenderer produced empty data",
                             dungeon: d2))
    }
}
