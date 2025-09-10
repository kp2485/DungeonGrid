//
//  StampTypingTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 9/10/25.
//


import Testing
@testable import DungeonGrid

@Suite struct StampTypingTests {
    @Test("Stamp labels are canonical (a, tiles, rid)")
    func labels() {
        let s: Stamp = (Point(1,1), [Point(1,1)], nil) // positional; labels come from Stamp
        #expect(s.a == Point(1,1))
        #expect(s.tiles.count == 1)
        #expect(s.rid == nil)
    }
}