//
//  PlacementTests.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Testing
@testable import DungeonGrid

@Suite struct PlacementTests {

    @Test("Deterministic placements with same seed")
    func deterministic() {
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39, algorithm: .bsp(BSPOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: 123
        )
        let index = DungeonIndex(d)

        let pol = PlacementPolicy(count: 15, density: nil, regionClass: .any,
                                  excludeDoorTiles: true,
                                  minDistanceFromEntrance: 5,
                                  avoidLOSFromEntrance: false,
                                  doorsTransparentForLOS: true,
                                  minSpacing: 2)

        let p1 = Placer.plan(in: d, index: index, seed: 999, kind: "enemy", policy: pol)
        let p2 = Placer.plan(in: d, index: index, seed: 999, kind: "enemy", policy: pol)
        #expect(p1 == p2)
    }

    @Test("Rooms-only vs corridors-only")
    func regionClassRespect() {
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39, algorithm: .uniformRooms(UniformRoomsOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: 77
        )
        let index = DungeonIndex(d)

        let (labels, kinds, w, _) = Regions.labelCells(d)
        func isRoom(_ rid: RegionID?) -> Bool {
            guard let rid, let k = kinds[rid] else { return false }
            if case .room = k { return true } else { return false }
        }

        var pol = PlacementPolicy()
        pol.count = 12
        pol.regionClass = .roomsOnly
        let rooms = Placer.plan(in: d, index: index, seed: 1, kind: "loot", policy: pol)
        #expect(!rooms.isEmpty)
        for r in rooms {
            let rid = labels[r.position.y * w + r.position.x]
            #expect(isRoom(rid))
        }

        pol.regionClass = .corridorsOnly
        let corrs = Placer.plan(in: d, index: index, seed: 1, kind: "loot", policy: pol)
        #expect(!corrs.isEmpty)
        for r in corrs {
            let rid = labels[r.position.y * w + r.position.x]
            #expect(!isRoom(rid))
        }
    }

    @Test("Minimum spacing is honored (Manhattan)")
    func spacingRespected() {
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39, algorithm: .bsp(BSPOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: 33
        )
        let index = DungeonIndex(d)

        var pol = PlacementPolicy()
        pol.count = 20
        pol.minSpacing = 4
        let pts = Placer.plan(in: d, index: index, seed: 5, kind: "spawn", policy: pol).map(\.position)

        for i in 0..<pts.count {
            for j in (i+1)..<pts.count {
                let m = abs(pts[i].x - pts[j].x) + abs(pts[i].y - pts[j].y)
                #expect(m >= 4)
            }
        }
    }

    @Test("Avoid LOS from entrance and avoid door tiles")
    func avoidLOSAndDoors() {
        let d = DungeonGrid.generate(
            config: .init(width: 61, height: 39, algorithm: .bsp(BSPOptions()),
                          ensureConnected: true, placeDoorsAndTags: true),
            seed: 55
        )
        guard let s = d.entrance else { return }
        let index = DungeonIndex(d)

        var pol = PlacementPolicy()
        pol.count = 12
        pol.avoidLOSFromEntrance = true
        pol.doorsTransparentForLOS = true
        pol.excludeDoorTiles = true
        pol.minDistanceFromEntrance = 3
        pol.regionClass = .any

        let ps = Placer.plan(in: d, index: index, seed: 101, kind: "enemy", policy: pol)

        // None should be a door, and none visible from entrance (with given policy)
        for p in ps {
            #expect(d.grid[p.position.x, p.position.y] != .door)
            #expect(!Visibility.hasLineOfSight(in: d, from: s, to: p.position,
                                              policy: .init(doorTransparent: true)))
        }
    }
}
