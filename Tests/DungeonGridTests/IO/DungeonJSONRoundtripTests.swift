//
//  DungeonJSONRoundtripTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//

import Foundation
import Testing
@testable import DungeonGrid

@Suite struct DungeonJSONRoundtripTests {

    @Test("encode → decode → encode roundtrip produces identical bytes")
    func roundtripStable() {
        // Use a config with doors/tags to exercise more fields.
        let cfg = DungeonConfig(width: 61, height: 39,
                                algorithm: .bsp(BSPOptions()),
                                ensureConnected: true,
                                placeDoorsAndTags: true)
        let d1 = DungeonGrid.generate(config: cfg, seed: 424242)

        // 1) Encode original (throws)
        let data1: Data
        do {
            data1 = try DungeonJSON.encode(d1)
        } catch {
            #expect(Bool(false), "DungeonJSON.encode failed: \(error)")
            return
        }
        #expect(!data1.isEmpty, "DungeonJSON.encode produced empty data")

        // 2) Decode back to Dungeon (throws)
        let d2: Dungeon
        do {
            d2 = try DungeonJSON.decode(data1)
        } catch {
            #expect(Bool(false), "DungeonJSON.decode failed: \(error)")
            return
        }

        // 3) Re-encode and compare bytes (throws)
        let data2: Data
        do {
            data2 = try DungeonJSON.encode(d2)
        } catch {
            #expect(Bool(false), "DungeonJSON re-encode failed: \(error)")
            return
        }
        #expect(!data2.isEmpty, "Re-encode produced empty data")

        if data1 != data2 {
            let why = diffJSONData(data1, data2)
            #expect(Bool(false), "JSON roundtrip mismatch: \(why)\n(data1: \(data1.count) bytes, data2: \(data2.count) bytes)")
        }

        #expect(data1 == data2)
    }

    @Test("decode(enc(d)) preserves core geometry and tags")
    func preservesGeometry() {
        let cfg = DungeonConfig(width: 41, height: 25,
                                algorithm: .uniformRooms(UniformRoomsOptions()),
                                ensureConnected: true,
                                placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 9001)

        // Encode (throws)
        let data: Data
        do {
            data = try DungeonJSON.encode(d)
        } catch {
            #expect(Bool(false), "DungeonJSON.encode failed: \(error)")
            return
        }

        // Decode (throws)
        let d2: Dungeon
        do {
            d2 = try DungeonJSON.decode(data)
        } catch {
            #expect(Bool(false), "DungeonJSON.decode failed: \(error)")
            return
        }

        // Tiles, edges, and (if present) S/E should match.
        #expect(d.grid.tiles == d2.grid.tiles, "Grid tiles differ after roundtrip")
        #expect(d.edges.h == d2.edges.h && d.edges.v == d2.edges.v, "Edges differ after roundtrip")

        if let s1 = d.entrance, let s2 = d2.entrance {
            #expect(s1 == s2, "Entrance changed after roundtrip")
        }
        if let e1 = d.exit, let e2 = d2.exit {
            #expect(e1 == e2, "Exit changed after roundtrip")
        }
    }
}
