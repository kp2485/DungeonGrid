//
//  DeterminismTests.swift
//  DungeonGridTests
//
//  Ensures identical seeds produce identical outputs across algorithms and pipeline steps.
//

import Foundation
import Testing
@testable import DungeonGrid

@Suite struct DeterminismTests {

    private func json(_ d: Dungeon) throws -> Data {
        try DungeonJSON.encode(d)
    }

    private func checkEqual(_ a: Dungeon, _ b: Dungeon, file: StaticString = #fileID, line: UInt = #line) {
        do {
            let da = try json(a)
            let db = try json(b)
            #expect(da == db, "Dungeons differ for same seed", sourceLocation: SourceLocation(fileID: file, line: line))
        } catch {
            #expect(Bool(false), "Encoding failed: \(error)", sourceLocation: SourceLocation(fileID: file, line: line))
        }
    }

    @Test("BSP generator determinism")
    func bsp() {
        var gen = BSPGenerator(options: BSPOptions())
        let seed: UInt64 = 0xB5P
        let a = gen.generate(width: 61, height: 39, seed: seed)
        let b = gen.generate(width: 61, height: 39, seed: seed)
        checkEqual(a, b)
    }

    @Test("Maze generator determinism")
    func maze() {
        var gen = MazeGenerator(options: MazeOptions())
        let seed: UInt64 = 0xMAZ3
        let a = gen.generate(width: 61, height: 39, seed: seed)
        let b = gen.generate(width: 61, height: 39, seed: seed)
        checkEqual(a, b)
    }

    @Test("Caves generator determinism")
    func caves() {
        var gen = CavesGenerator(options: CavesOptions())
        let seed: UInt64 = 0xCAV35
        let a = gen.generate(width: 61, height: 39, seed: seed)
        let b = gen.generate(width: 61, height: 39, seed: seed)
        checkEqual(a, b)
    }

    @Test("UniformRooms generator determinism")
    func uniformRooms() {
        var gen = UniformRoomsGenerator(options: UniformRoomsOptions())
        let seed: UInt64 = 0xUR00M5
        let a = gen.generate(width: 61, height: 39, seed: seed)
        let b = gen.generate(width: 61, height: 39, seed: seed)
        checkEqual(a, b)
    }

    @Test("Entry.generate determinism (with post flags)")
    func entryGenerate() {
        let cfg = DungeonConfig(width: 61, height: 39, algorithm: .bsp(BSPOptions()), ensureConnected: true, placeDoorsAndTags: true)
        let seed: UInt64 = 12345
        let a = DungeonGrid.generate(config: cfg, seed: seed)
        let b = DungeonGrid.generate(config: cfg, seed: seed)
        checkEqual(a, b)
    }

    @Test("Full pipeline determinism (steps + placements)")
    func fullPipeline() {
        let cfg = DungeonConfig(width: 61, height: 39, algorithm: .maze(MazeOptions()), ensureConnected: true, placeDoorsAndTags: true)
        let seed: UInt64 = 98765

        var pol1 = PlacementPolicy(); pol1.count = 12; pol1.regionClass = .roomsOnly; pol1.minSpacing = 2
        var pol2 = PlacementPolicy(); pol2.count = 18; pol2.regionClass = .corridorsOnly; pol2.excludeDoorTiles = true

        let reqs: [PlacementRequest] = [
            .init(kind: "enemy", policy: pol1, seed: SeedDeriver.derive(seed, "place.enemy")),
            .init(kind: "loot.health", policy: pol2, seed: SeedDeriver.derive(seed, "place.loot"))
        ]

        let A = DungeonGrid.generateFull(
            config: cfg,
            seed: seed,
            ensureConnected: nil,
            placeDoorsAndTags: nil,
            doorPolicy: .init(),
            locks: (maxLocks: 2, doorBias: 2),
            themes: nil,
            requests: reqs
        )

        let B = DungeonGrid.generateFull(
            config: cfg,
            seed: seed,
            ensureConnected: nil,
            placeDoorsAndTags: nil,
            doorPolicy: .init(),
            locks: (maxLocks: 2, doorBias: 2),
            themes: nil,
            requests: reqs
        )

        checkEqual(A.dungeon, B.dungeon)
        #expect(A.placements == B.placements)
        #expect(A.locksPlan == B.locksPlan)
        #expect(A.themeAssignment == B.themeAssignment)
    }
}


