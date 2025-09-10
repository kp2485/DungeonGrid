//
//  PlacementTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Testing
@testable import DungeonGrid

@Suite struct PlacementTests {

    @Test("Deterministic placements with same seed (across fuzz seeds)")
    func deterministic() {
        let seeds: [UInt64] = TestEnv.fuzzSeeds
        for worldSeed in seeds {
            let d = DungeonGrid.generate(
                config: .init(width: 61, height: 39, algorithm: .bsp(BSPOptions()),
                              ensureConnected: true, placeDoorsAndTags: true),
                seed: worldSeed
            )

            let pol = PlacementPolicy(count: 15, density: nil, regionClass: .any,
                                      excludeDoorTiles: true,
                                      minDistanceFromEntrance: 5,
                                      avoidLOSFromEntrance: false,
                                      doorsTransparentForLOS: true,
                                      minSpacing: 2)

            let p1 = Placer.plan(in: d, seed: 999, kind: "enemy", policy: pol)
            let p2 = Placer.plan(in: d, seed: 999, kind: "enemy", policy: pol)

            #expect(p1 == p2, "Placement determinism failed for worldSeed \(worldSeed)")
        }
    }

    @Test("Rooms-only vs corridors-only")
    func regionClassRespect() {
        for worldSeed in TestEnv.fuzzSeeds {
            let d = DungeonGrid.generate(
                config: .init(width: 61, height: 39, algorithm: .uniformRooms(UniformRoomsOptions()),
                              ensureConnected: true, placeDoorsAndTags: true),
                seed: worldSeed
            )
            let (labels, kinds, w, _) = Regions.labelCells(d)
            func isRoom(_ rid: RegionID?) -> Bool {
                guard let rid, let k = kinds[rid] else { return false }
                if case .room = k { return true } else { return false }
            }

            var pol = PlacementPolicy()
            pol.count = 12
            pol.regionClass = .roomsOnly
            let rooms = Placer.plan(in: d, seed: 1, kind: "loot", policy: pol)
            #expect(!rooms.isEmpty, "Expected some room placements for worldSeed \(worldSeed)")
            for r in rooms {
                let rid = labels[r.position.y * w + r.position.x]
                #expect(isRoom(rid), "Non-room placement in roomsOnly policy at \(r.position)")
            }

            pol.regionClass = .corridorsOnly
            let corrs = Placer.plan(in: d, seed: 1, kind: "loot", policy: pol)
            #expect(!corrs.isEmpty, "Expected some corridor placements for worldSeed \(worldSeed)")
            for r in corrs {
                let rid = labels[r.position.y * w + r.position.x]
                #expect(!isRoom(rid), "Room placement in corridorsOnly policy at \(r.position)")
            }
        }
    }

    @Test("Minimum spacing is honored (Manhattan)")
    func spacingRespected() {
        // Keep this one lighter: run on just the first fuzz seed.
        guard let worldSeed = TestEnv.fuzzSeeds.first else { return }
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39, algorithm: .bsp(BSPOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: worldSeed
        )
        var pol = PlacementPolicy()
        pol.count = 20
        pol.minSpacing = 4
        let ps = Placer.plan(in: d, seed: 5, kind: "spawn", policy: pol)

        var ok = true
        for i in 0..<ps.count {
            for j in (i+1)..<ps.count {
                let a = ps[i].position, b = ps[j].position
                let m = abs(a.x - b.x) + abs(a.y - b.y)
                if m < 4 { ok = false }
            }
        }
        #expect(ok, "Min spacing violated (expected ≥ 4)")
    }

    @Test("Avoid LOS from entrance and avoid door tiles")
    func avoidLOSAndDoors() {
        guard let worldSeed = TestEnv.fuzzSeeds.first else { return }
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39, algorithm: .bsp(BSPOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: worldSeed
        )
        guard let s = d.entrance else { return }

        var pol = PlacementPolicy()
        pol.count = 12
        pol.avoidLOSFromEntrance = true
        pol.doorsTransparentForLOS = true
        pol.excludeDoorTiles = true
        pol.minDistanceFromEntrance = 3
        pol.regionClass = .any

        let ps = Placer.plan(in: d, seed: 101, kind: "enemy", policy: pol)

        for p in ps {
            #expect(d.grid[p.position.x, p.position.y] != .door,
                    "Placement landed on a door tile at \(p.position)")
            #expect(!Visibility.hasLineOfSight(in: d,
                                              from: s,
                                              to: p.position,
                                              policy: .init(doorTransparent: true)),
                    "Placement visible from entrance at \(p.position)")
        }
    }
}
