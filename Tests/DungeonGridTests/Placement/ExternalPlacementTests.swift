//
//  ExternalPlacementTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//

import Testing
@testable import DungeonGrid

@Suite struct ExternalPlacementTests {
    @Test("Placing external items is deterministic")
    func deterministic() {
        let d = DungeonGrid.generate(config: .init(width: 41, height: 25, algorithm: .bsp(BSPOptions()), ensureConnected: true, placeDoorsAndTags: true),
                                     seed: 123)
        var p = PlacementPolicy(); p.count = 1; p.regionClass = .roomsOnly
        let items: [AnyPlaceable] = [
            AnyPlaceable(id: "gob", kind: "enemy.goblin", footprint: .single, policy: p),
            AnyPlaceable(id: "chA", kind: "chest",        footprint: .single, policy: p),
            AnyPlaceable(id: "chB", kind: "chest",        footprint: .single, policy: p),
        ]
        let idx = DungeonIndex(d)
        let r1 = ExternalPlacer.place(in: d, index: idx, themes: nil, seed: 555, items: items)
        let r2 = ExternalPlacer.place(in: d, index: idx, themes: nil, seed: 555, items: items)
        #expect(r1 == r2)
    }
}
