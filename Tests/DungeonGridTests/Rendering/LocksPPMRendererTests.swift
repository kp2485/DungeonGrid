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
        let cfg = DungeonConfig(
            width: 41,
            height: 25,
            algorithm: .bsp(BSPOptions()),
            ensureConnected: true,
            placeDoorsAndTags: true
        )
        let d = DungeonGrid.generate(config: cfg, seed: worldSeed)

        let g = DungeonIndex(d).graph
        let (d2, plan) = LocksPlanner.planAndApply(
            d,
            graph: g,
            entrance: d.entrance,
            maxLocks: 2,
            doorBias: 2
        )

        // Expect at least one lock if we planned locks.
        if plan.locks.count == 0 { TestDebug.print(d2) }
        #expect(plan.locks.count > 0)

        let ppm = LocksPPMRenderer.render(d2)
        if ppm.isEmpty { TestDebug.print(d2) }
        #expect(!ppm.isEmpty)
    }
}
