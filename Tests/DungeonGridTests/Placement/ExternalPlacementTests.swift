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

// MARK: - Advanced external placement: multi-tile footprints + groups

@Suite struct ExternalPlacementAdvancedTests {

    // Helper: expand placed footprint to all occupied tiles
    func footprintTiles(anchor: Point, footprint: Footprint) -> [Point] {
        switch footprint {
        case .single:
            return [anchor]
        case .rect(let w, let h):
            var pts: [Point] = []
            pts.reserveCapacity(w*h)
            for dy in 0..<h {
                for dx in 0..<w {
                    pts.append(Point(anchor.x + dx, anchor.y + dy))
                }
            }
            return pts
        case .mask(let offs):
            return offs.map { Point(anchor.x + $0.x, anchor.y + $0.y) }
        }
    }

    @Test("Multi-tile footprints: rect + mask fit, do not overlap, and stay on passable tiles")
    func multiTileFootprints() {
        guard let worldSeed = TestEnv.fuzzSeeds.first else { return }

        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39, algorithm: .bsp(BSPOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: worldSeed
        )
        let index = DungeonIndex(d)

        // Items: a 2x2 "ogre", an L-shaped "treasure alcove", plus a couple single tiles
        var policyRoom = PlacementPolicy()
        policyRoom.count = 1
        policyRoom.regionClass = .roomsOnly
        policyRoom.excludeDoorTiles = true
        policyRoom.minSpacing = 2

        let ogre = AnyPlaceable(
            id: "ogre-2x2",
            kind: "enemy.ogre",
            footprint: .rect(width: 2, height: 2),
            policy: policyRoom
        )

        let lMask: [Point] = [Point(0,0), Point(1,0), Point(0,1)]
        let treasure = AnyPlaceable(
            id: "treasure-L",
            kind: "chest",
            footprint: .mask(lMask),
            policy: policyRoom
        )

        let gobA = AnyPlaceable(
            id: "gob-A",
            kind: "enemy.goblin",
            footprint: .single,
            policy: policyRoom
        )
        let gobB = AnyPlaceable(
            id: "gob-B",
            kind: "enemy.goblin",
            footprint: .single,
            policy: policyRoom
        )

        let items = [ogre, treasure, gobA, gobB]

        // Map item IDs (if String) → item
        let byID: [String: AnyPlaceable] = Dictionary(uniqueKeysWithValues:
            items.compactMap { it in
                guard let sid = it.id as? String else { return nil }
                return (sid, it)
            }
        )

        let res = ExternalPlacer.place(in: d, index: index, themes: nil, seed: d.seed, items: items)

        // Expect all items to be placed (only for those with String IDs)
        let idsPlaced = Set(res.placements.map(\.id))
        for it in items {
            if let sid = it.id as? String {
                #expect(idsPlaced.contains(sid), "Item \(sid) failed to place")
            }
        }

        // Build an occupancy map from the placements and asserted footprints
        var seen = Set<Int>()
        let w = d.grid.width
        @inline(__always) func idx(_ p: Point) -> Int { p.y * w + p.x }

        for p in res.placements {
            guard let it = byID[p.id] else {
                #expect(Bool(false), "Missing item for placement \(p.id)")
                continue
            }
            let tiles = footprintTiles(anchor: p.position, footprint: it.footprint)

            // All tiles must be passable and (optionally) non-door
            for t in tiles {
                #expect(d.grid[t.x, t.y].isPassable, "Footprint covers non-passable tile at \(t) for \(p.id)")
                if it.policy.excludeDoorTiles {
                    #expect(d.grid[t.x, t.y] != .door, "Footprint covers door tile at \(t) for \(p.id)")
                }
            }

            // No overlaps across items
            for t in tiles {
                let li = idx(t)
                #expect(!seen.contains(li), "Footprint overlap detected at \(t) for \(p.id)")
                seen.insert(li)
            }
        }
    }

    @Test("Group constraints: members share region, honor min/max anchor distances, deterministic")
    func groupConstraints() {
        // Use two seeds to validate determinism under same inputs
        let seeds = Array(TestEnv.fuzzSeeds.prefix(2))
        for worldSeed in seeds {
            let d = DungeonGrid.generate(
                config: .init(width: 61, height: 39, algorithm: .uniformRooms(UniformRoomsOptions()),
                              ensureConnected: true, placeDoorsAndTags: true),
                seed: worldSeed
            )

            let index = DungeonIndex(d)
            var pol = PlacementPolicy()
            pol.count = 1
            pol.regionClass = .roomsOnly
            pol.minSpacing = 1
            pol.excludeDoorTiles = true

            // Three goblins that must end up in the same region, within radius 6 of each other, and not identical anchors
            let goblins: [AnyPlaceable] = (0..<3).map { i in
                AnyPlaceable(id: "squad-gob-\(i)", kind: "enemy.goblin", footprint: .single, policy: pol)
            }
            let group = PlacementGroup(
                id: "gob-squad-A",
                memberIDs: goblins.map(\.id), // [AnyHashable] in API
                maxAnchorDistance: 6,
                minAnchorDistance: 1,
                sameRegion: true,
                sameTheme: false
            )

            let res1 = ExternalPlacer.place(in: d, index: index, themes: nil, seed: d.seed, items: goblins, groups: [group])
            let res2 = ExternalPlacer.place(in: d, index: index, themes: nil, seed: d.seed, items: goblins, groups: [group])

            // Determinism
            #expect(res1 == res2)

            // All placed (convert AnyHashable → String for lookups)
            let pmap = Dictionary(uniqueKeysWithValues: res1.placements.map { ($0.id, $0) })
            for it in goblins {
                if let sid = it.id as? String {
                    #expect(pmap[sid] != nil, "Group member \(sid) not placed")
                }
            }

            // Same region + distance constraints
            let ps = goblins.compactMap { ($0.id as? String).flatMap { pmap[$0] } }
            guard ps.count == goblins.count else { return }

            if let r0 = ps.first?.region {
                for p in ps { #expect(p.region == r0, "Group member \(p.id) not in same region as others") }
            }

            for i in 0..<ps.count {
                for j in (i+1)..<ps.count {
                    let a = ps[i].position, b = ps[j].position
                    let m = abs(a.x - b.x) + abs(a.y - b.y)
                    #expect(m >= 1, "Group members at identical anchors")
                    #expect(m <= 6, "Group members too far apart (m=\(m) > 6)")
                }
            }
        }
    }
}
