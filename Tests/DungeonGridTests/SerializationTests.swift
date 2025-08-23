//
//  SerializationTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Testing
@testable import DungeonGrid

@Suite struct SerializationTests {

    @Test("Dungeon JSON round-trip preserves tiles, edges, rooms, entrance/exit")
    func roundTrip() throws {
        let cfg = DungeonConfig(
            width: 61, height: 39,
            algorithm: .bsp(BSPOptions()),
            ensureConnected: true,
            placeDoorsAndTags: true
        )
        let d1 = DungeonGrid.generate(config: cfg, seed: 4242)

        let data = try DungeonJSON.encode(d1)
        let d2 = try DungeonJSON.decode(data)

        // Tiles and edges should match exactly
        #expect(d1.grid.width == d2.grid.width && d1.grid.height == d2.grid.height)
        #expect(d1.grid.tiles == d2.grid.tiles)
        #expect(d1.edges.h == d2.edges.h)
        #expect(d1.edges.v == d2.edges.v)

        // Rooms: same count and rectangles (order-agnostic)
        #expect(d1.rooms.count == d2.rooms.count)

        let a = d1.rooms
            .sorted { $0.id < $1.id }
            .map { [$0.id, $0.rect.x, $0.rect.y, $0.rect.width, $0.rect.height] }

        let b = d2.rooms
            .sorted { $0.id < $1.id }
            .map { [$0.id, $0.rect.x, $0.rect.y, $0.rect.width, $0.rect.height] }

        #expect(a == b)

        // Entrance/exit: equal or both nil
        switch (d1.entrance, d2.entrance) {
        case (nil, nil): break
        case let (e1?, e2?): #expect(e1 == e2)
        default: #expect(Bool(false), "entrance mismatch")
        }
        switch (d1.exit, d2.exit) {
        case (nil, nil): break
        case let (e1?, e2?): #expect(e1 == e2)
        default: #expect(Bool(false), "exit mismatch")
        }

        // Doors tiles are optional metadata; compare as sets (order-insensitive)
        #expect(Set(d1.doors) == Set(d2.doors))
    }
}
