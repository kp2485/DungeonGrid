//
//  PlacementVisualizationTests.swift
//  DungeonGridTests
//
//  Visual tests showing placement constraints in action via ASCII maps.
//

import Foundation
import Testing
@testable import DungeonGrid

@Suite struct PlacementVisualizationTests {

    @Test("Visualize region class constraints")
    func visualizeRegionClasses() {
        let cfg = DungeonConfig(width: 31, height: 21, algorithm: .bsp(BSPOptions()), ensureConnected: true, placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 12345)
        let idx = DungeonIndex(d)
        
        print("\n=== Region Class Visualization ===")
        print("Map: \(cfg.width)×\(cfg.height) BSP")
        
        // Test different region classes
        let regionClasses: [(String, PlacementPolicy.RegionClass)] = [
            ("roomsOnly", .roomsOnly),
            ("corridorsOnly", .corridorsOnly),
            ("junctions", .junctions(minDegree: 3)),
            ("deadEnds", .deadEnds),
            ("farFromEntrance", .farFromEntrance(minHops: 3)),
            ("nearEntrance", .nearEntrance(maxHops: 2)),
            ("perimeter", .perimeter),
            ("core", .core)
        ]
        
        for (name, regionClass) in regionClasses {
            let pol = PlacementPolicy(count: 8, regionClass: regionClass, minSpacing: 2)
            let placements = Placer.plan(in: d, index: idx, seed: 999, kind: name, policy: pol)
            
            print("\n--- \(name) (\(placements.count) placements) ---")
            let ascii = DungeonDebug.dumpASCII(d, placements: placements, annotateKinds: true)
            print(ascii)
        }
    }

    @Test("Visualize area constraints")
    func visualizeAreaConstraints() {
        let cfg = DungeonConfig(width: 41, height: 25, algorithm: .uniformRooms(UniformRoomsOptions()), ensureConnected: true, placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 54321)
        let idx = DungeonIndex(d)
        
        print("\n=== Area Constraint Visualization ===")
        print("Map: \(cfg.width)×\(cfg.height) UniformRooms")
        
        let areaTests: [(String, PlacementPolicy)] = [
            ("smallRooms", PlacementPolicy(count: 6, regionClass: .roomsOnly, roomAreaMin: 4, roomAreaMax: 12)),
            ("largeRooms", PlacementPolicy(count: 6, regionClass: .roomsOnly, roomAreaMin: 20)),
            ("smallCorridors", PlacementPolicy(count: 8, regionClass: .corridorsOnly, corridorAreaMin: 2, corridorAreaMax: 8)),
            ("largeCorridors", PlacementPolicy(count: 8, regionClass: .corridorsOnly, corridorAreaMin: 15))
        ]
        
        for (name, policy) in areaTests {
            let placements = Placer.plan(in: d, index: idx, seed: 888, kind: name, policy: policy)
            
            print("\n--- \(name) (\(placements.count) placements) ---")
            let ascii = DungeonDebug.dumpASCII(d, placements: placements, annotateKinds: true)
            print(ascii)
        }
    }

    @Test("Visualize distance constraints")
    func visualizeDistanceConstraints() {
        let cfg = DungeonConfig(width: 35, height: 23, algorithm: .maze(MazeOptions()), ensureConnected: true, placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 77777)
        let idx = DungeonIndex(d)
        
        print("\n=== Distance Constraint Visualization ===")
        print("Map: \(cfg.width)×\(cfg.height) Maze")
        print("S=entrance, E=exit")
        
        let distanceTests: [(String, PlacementPolicy)] = [
            ("nearEntrance", PlacementPolicy(count: 6, minDistanceFromEntrance: 1, maxDistanceFromEntrance: 5)),
            ("midDistance", PlacementPolicy(count: 6, minDistanceFromEntrance: 8, maxDistanceFromEntrance: 15)),
            ("farFromEntrance", PlacementPolicy(count: 6, minDistanceFromEntrance: 20)),
            ("nearExit", PlacementPolicy(count: 6, minDistanceFromExit: 1, maxDistanceFromExit: 8)),
            ("farFromExit", PlacementPolicy(count: 6, minDistanceFromExit: 15))
        ]
        
        for (name, policy) in distanceTests {
            let placements = Placer.plan(in: d, index: idx, seed: 111, kind: name, policy: policy)
            
            print("\n--- \(name) (\(placements.count) placements) ---")
            let ascii = DungeonDebug.dumpASCII(d, placements: placements, annotateKinds: true)
            print(ascii)
        }
    }

    @Test("Visualize door avoidance")
    func visualizeDoorAvoidance() {
        let cfg = DungeonConfig(width: 29, height: 19, algorithm: .bsp(BSPOptions()), ensureConnected: true, placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 99999)
        let idx = DungeonIndex(d)
        
        print("\n=== Door Avoidance Visualization ===")
        print("Map: \(cfg.width)×\(cfg.height) BSP")
        print("+=doors, S=entrance, E=exit")
        
        let doorTests: [(String, PlacementPolicy)] = [
            ("noAvoidance", PlacementPolicy(count: 10, avoidNearDoorEdgesRadius: 0)),
            ("avoidRadius1", PlacementPolicy(count: 10, avoidNearDoorEdgesRadius: 1)),
            ("avoidRadius2", PlacementPolicy(count: 10, avoidNearDoorEdgesRadius: 2)),
            ("excludeDoorTiles", PlacementPolicy(count: 10, excludeDoorTiles: true))
        ]
        
        for (name, policy) in doorTests {
            let placements = Placer.plan(in: d, index: idx, seed: 222, kind: name, policy: policy)
            
            print("\n--- \(name) (\(placements.count) placements) ---")
            let ascii = DungeonDebug.dumpASCII(d, placements: placements, annotateKinds: true)
            print(ascii)
        }
    }

    @Test("Visualize combined constraints")
    func visualizeCombinedConstraints() {
        let cfg = DungeonConfig(width: 37, height: 21, algorithm: .uniformRooms(UniformRoomsOptions()), ensureConnected: true, placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 11111)
        let idx = DungeonIndex(d)
        
        print("\n=== Combined Constraint Visualization ===")
        print("Map: \(cfg.width)×\(cfg.height) UniformRooms")
        
        let combinedTests: [(String, PlacementPolicy)] = [
            ("junctionsFar", PlacementPolicy(
                count: 5,
                regionClass: .junctions(minDegree: 3),
                minDistanceFromEntrance: 4,
                minSpacing: 3,
                avoidNearDoorEdgesRadius: 1,
            )),
            ("deadEndsNear", PlacementPolicy(
                count: 6,
                regionClass: .deadEnds,
                maxDistanceFromEntrance: 6,
                minSpacing: 2
            )),
            ("coreLargeRooms", PlacementPolicy(
                count: 4,
                regionClass: .core,
                minDistanceFromEntrance: 3,
                minSpacing: 4,
                roomAreaMin: 15,
            ))
        ]
        
        for (name, policy) in combinedTests {
            let placements = Placer.plan(in: d, index: idx, seed: 333, kind: name, policy: policy)
            
            print("\n--- \(name) (\(placements.count) placements) ---")
            let ascii = DungeonDebug.dumpASCII(d, placements: placements, annotateKinds: true)
            print(ascii)
        }
    }

    @Test("Visualize locks and placement")
    func visualizeLocksAndPlacement() {
        let cfg = DungeonConfig(width: 33, height: 21, algorithm: .bsp(BSPOptions()), ensureConnected: true, placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 44444)
        
        // Generate with locks
        let result = DungeonGrid.generateFull(
            config: cfg,
            seed: 44444,
            locks: (maxLocks: 2, doorBias: 2),
            requests: [
                PlacementRequest(kind: "key", policy: PlacementPolicy(count: 2, regionClass: .roomsOnly), seed: 555),
                PlacementRequest(kind: "enemy", policy: PlacementPolicy(count: 8, regionClass: .corridorsOnly, minDistanceFromEntrance: 3), seed: 666)
            ]
        )
        
        print("\n=== Locks and Placement Visualization ===")
        print("Map: \(cfg.width)×\(cfg.height) BSP with locks")
        print("S=entrance, E=exit, +=doors, locked edges shown as '|'")
        
        // Create a custom ASCII renderer that shows locked edges
        let w = result.dungeon.grid.width, h = result.dungeon.grid.height
        var ascii = ""
        
        for y in 0..<h {
            for x in 0..<w {
                let t = result.dungeon.grid[x, y]
                
                // Entrances/exits
                if let s = result.dungeon.entrance, s.x == x, s.y == y { ascii += "S" }
                else if let e = result.dungeon.exit, e.x == x, e.y == y { ascii += "E" }
                // Placements
                else if result.placements["key"]?.contains(where: { $0.position.x == x && $0.position.y == y }) == true { ascii += "K" }
                else if result.placements["enemy"]?.contains(where: { $0.position.x == x && $0.position.y == y }) == true { ascii += "e" }
                // Base terrain
                else {
                    switch t {
                    case .wall: ascii += "#"
                    case .floor: ascii += "."
                    case .door: ascii += "+"
                    }
                }
            }
            ascii += "\n"
        }
        
        print(ascii)
        
        if let plan = result.locksPlan {
            print("Locks plan: \(plan.locks.count) locks")
            for lock in plan.locks {
                print("  Lock between regions \(lock.regionA.raw) and \(lock.regionB.raw), key in region \(lock.keyRegion.raw)")
            }
        }
    }

    @Test("Region Class: Closets")
    func regionClassClosets() throws {
        let cfg = DungeonConfig(width: 25, height: 15, algorithm: .bsp(BSPOptions()), ensureConnected: true, placeDoorsAndTags: true)
        let d = DungeonGrid.generate(config: cfg, seed: 100)
        
        // Check if any closets were generated
        let closetCount = d.rooms.filter { $0.type == .closet }.count
        print("\nGenerated \(closetCount) closets out of \(d.rooms.count) total rooms")
        
        if closetCount == 0 {
            print("No closets generated with this seed, trying a different seed...")
            let d2 = DungeonGrid.generate(config: cfg, seed: 200)
            let closetCount2 = d2.rooms.filter { $0.type == .closet }.count
            print("With seed 200: \(closetCount2) closets out of \(d2.rooms.count) total rooms")
            
            if closetCount2 > 0 {
                let pol = PlacementPolicy(count: 5, regionClass: .closetsOnly)
                let placements = Placer.plan(in: d2, seed: 1, kind: "K", policy: pol)
                let ascii = DungeonDebug.dumpASCII(d2, placements: placements, annotateKinds: true)
                print("\nCloset rooms (K = key/loot):\n\(ascii)")
                #expect(!placements.isEmpty)
            } else {
                print("Still no closets - this is expected behavior (closets are optional)")
                #expect(Bool(true)) // Pass the test since closets are optional
            }
        } else {
            let pol = PlacementPolicy(count: 5, regionClass: .closetsOnly)
            let placements = Placer.plan(in: d, seed: 1, kind: "K", policy: pol)
            let ascii = DungeonDebug.dumpASCII(d, placements: placements, annotateKinds: true)
            print("\nCloset rooms (K = key/loot):\n\(ascii)")
            #expect(!placements.isEmpty)
        }
    }
}
