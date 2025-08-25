//
//  SeedDeriverTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//


import Testing
@testable import DungeonGrid

@Suite struct SeedDeriverTests {
    @Test("derive is deterministic and label-sensitive")
    func stable() {
        let base: UInt64 = 12345
        let a = SeedDeriver.derive(base, "ensureConnected")
        let b = SeedDeriver.derive(base, "placeDoorsAndTag")
        let c = SeedDeriver.derive(base, "ensureConnected")
        #expect(a == c)
        #expect(a != b)
    }
}
