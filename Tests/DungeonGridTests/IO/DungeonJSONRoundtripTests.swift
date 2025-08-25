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
            #expect(expectOrDump(false,
                                 "DungeonJSON.encode failed: \(error)",
                                 dungeon: d1))
            return
        }
        #expect(expectOrDump(!data1.isEmpty,
                             "DungeonJSON.encode produced empty data",
                             dungeon: d1))

        // 2) Decode back to Dungeon (throws)
        let d2: Dungeon
        do {
            d2 = try DungeonJSON.decode(data1)
        } catch {
            #expect(expectOrDump(false,
                                 "DungeonJSON.decode failed: \(error)",
                                 dungeon: d1))
            return
        }

        // 3) Re-encode and compare bytes (throws)
        let data2: Data
        do {
            data2 = try DungeonJSON.encode(d2)
        } catch {
            #expect(expectOrDump(false,
                                 "DungeonJSON re-encode failed: \(error)",
                                 dungeon: d2))
            return
        }
        #expect(expectOrDump(!data2.isEmpty,
                             "Re-encode produced empty data",
                             dungeon: d2))

        if data1 != data2 {
            let why = diffJSONData(data1, data2)
            _ = expectOrDump(false,
                             "JSON roundtrip mismatch: \(why)\n(data1: \(data1.count) bytes, data2: \(data2.count) bytes)",
                             dungeon: d2)
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
            #expect(expectOrDump(false,
                                 "DungeonJSON.encode failed: \(error)",
                                 dungeon: d))
            return
        }

        // Decode (throws)
        let d2: Dungeon
        do {
            d2 = try DungeonJSON.decode(data)
        } catch {
            #expect(expectOrDump(false,
                                 "DungeonJSON.decode failed: \(error)",
                                 dungeon: d))
            return
        }

        // Tiles, edges, and (if present) S/E should match.
        #expect(expectOrDump(d.grid.tiles == d2.grid.tiles,
                             "Grid tiles differ after roundtrip",
                             dungeon: d2))
        #expect(expectOrDump(d.edges.h == d2.edges.h && d.edges.v == d2.edges.v,
                             "Edges differ after roundtrip",
                             dungeon: d2))

        if let s1 = d.entrance, let s2 = d2.entrance {
            #expect(expectOrDump(s1 == s2,
                                 "Entrance changed after roundtrip",
                                 dungeon: d2))
        }
        if let e1 = d.exit, let e2 = d2.exit {
            #expect(expectOrDump(e1 == e2,
                                 "Exit changed after roundtrip",
                                 dungeon: d2))
        }
    }
}
