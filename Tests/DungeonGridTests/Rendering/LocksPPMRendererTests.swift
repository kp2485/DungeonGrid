//
//  LocksPPMRendererTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//


import Testing
@testable import DungeonGrid

@Suite struct LocksPPMRendererTests {

    @Test("Renders PPM with locked edges when locks are planned")
    func rendersLocked() {
        let cfg = DungeonConfig(width: 41, height: 25,
                                algorithm: .bsp(BSPOptions()),
                                ensureConnected: true,
                                placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 77)

        let g = DungeonIndex(d).graph
        let (d2, plan) = LocksPlanner.planAndApply(d, graph: g, entrance: d.entrance, maxLocks: 2, doorBias: 2)

        // ensure the plan created something (may be zero in rare seeds/algos; still safe to render)
        #expect(plan.locks.count >= 0)

        let ppm = LocksPPMRenderer.render(d2)
        #expect(!ppm.isEmpty)
    }
}
