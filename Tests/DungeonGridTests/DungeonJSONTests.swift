//
//  DungeonJSONTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation
import Testing
@testable import DungeonGrid

@Suite struct DungeonJSONTests {

    @Test("Decode fails for unsupported version")
    func unsupportedVersion() {
        let json = """
        {
          "version": \(DungeonJSON.currentVersion + 999),
          "width": 4,
          "height": 4,
          "seed": 1,
          "tilesB64": "",
          "edgesHB64": "",
          "edgesVB64": "",
          "rooms": [],
          "entrance": null,
          "exit": null,
          "doorTiles": []
        }
        """.data(using: .utf8)!

        do {
            _ = try DungeonJSON.decode(json)
            #expect(false, "expected decode to throw on unsupported version")
        } catch {
            #expect(true) // ok
        }
    }

    @Test("Decode fails on bad Base64")
    func badBase64() {
        let json = """
        {
          "version": \(DungeonJSON.currentVersion),
          "width": 4,
          "height": 4,
          "seed": 1,
          "tilesB64": "!!!not-base64!!!",
          "edgesHB64": "also-bad",
          "edgesVB64": "still-bad",
          "rooms": [],
          "entrance": null,
          "exit": null,
          "doorTiles": []
        }
        """.data(using: .utf8)!

        do {
            _ = try DungeonJSON.decode(json)
            #expect(false, "expected decode to throw on bad Base64")
        } catch {
            #expect(true) // ok
        }
    }

    @Test("Decode fails when a room is out of bounds")
    func roomOutOfBounds() throws {
        // Start from a valid encoded snapshot…
        let d = DungeonGrid.generate(
            config: .init(width: 31, height: 21,
                          algorithm: .bsp(BSPOptions()),
                          ensureConnected: true,
                          placeDoorsAndTags: true),
            seed: 123
        )
        let data = try DungeonJSON.encode(d)

        // Decode the snapshot, then rebuild one with a bad room.
        let dec = JSONDecoder()
        let snap = try dec.decode(DungeonJSON.Snapshot.self, from: data)

        // Create a room that is guaranteed OOB (x = width)
        let badRoom = DungeonJSON.RoomSnap(id: 999, x: d.grid.width, y: 0, width: 3, height: 3)

        var newRooms = snap.rooms
        if newRooms.isEmpty {
            newRooms = [badRoom]
        } else {
            newRooms[0] = badRoom
        }

        // Rebuild a snapshot with modified rooms (Snapshot fields are lets)
        let snap2 = DungeonJSON.Snapshot(
            version: snap.version,
            width: snap.width,
            height: snap.height,
            seed: snap.seed,
            tilesB64: snap.tilesB64,
            edgesHB64: snap.edgesHB64,
            edgesVB64: snap.edgesVB64,
            rooms: newRooms,
            entrance: snap.entrance,
            exit: snap.exit,
            doorTiles: snap.doorTiles
        )

        let badData = try JSONEncoder().encode(snap2)
        do {
            _ = try DungeonJSON.decode(badData)
            #expect(false, "expected decode to throw on out-of-bounds room")
        } catch {
            #expect(true) // ok
        }
    }

    @Test("Round-trip fuzz: encode → decode → encode is stable; invariants hold")
    func roundTripFuzz() throws {
        let algos: [Algorithm] = [
            .bsp(BSPOptions()),
            .maze(MazeOptions()),
            .uniformRooms(UniformRoomsOptions())
        ]
        let sizes = [(41, 25), (33, 33), (29, 21)]

        var checked = 0
        for (w, h) in sizes {
            for (i, algo) in algos.enumerated() {
                let seed: UInt64 = UInt64(1000 + i * 17 + w + h)
                let d = DungeonGrid.generate(
                    config: .init(width: w, height: h, algorithm: algo,
                                  ensureConnected: true, placeDoorsAndTags: true),
                    seed: seed
                )

                // encode → decode
                let data1 = try DungeonJSON.encode(d)
                let d2 = try DungeonJSON.decode(data1)

                // invariants
                #expect(d.grid.width  == d2.grid.width)
                #expect(d.grid.height == d2.grid.height)
                #expect(d.seed == d2.seed)

                // tiles/edges equality
                #expect(d.grid.tiles == d2.grid.tiles)
                #expect(d.edges.h == d2.edges.h)
                #expect(d.edges.v == d2.edges.v)

                // entrance/exit/doors equality
                #expect(d.entrance == d2.entrance)
                #expect(d.exit == d2.exit)
                #expect(Set(d.doors) == Set(d2.doors))

                // rooms equality by (id,rect) — use simple string keys to keep type-checking cheap
                let r1 = d.rooms
                    .map { "\($0.id):\($0.rect.x),\($0.rect.y),\($0.rect.width),\($0.rect.height)" }
                    .sorted()
                let r2 = d2.rooms
                    .map { "\($0.id):\($0.rect.x),\($0.rect.y),\($0.rect.width),\($0.rect.height)" }
                    .sorted()
                #expect(r1 == r2)
                
                // encode again; ensure canonical form is stable
                let data2 = try DungeonJSON.encode(d2)
                #expect(data1 == data2)

                checked += 1
            }
        }
        #expect(checked == sizes.count * algos.count)
    }
}
