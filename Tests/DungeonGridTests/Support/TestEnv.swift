//
//  TestEnv.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  CI/local knobs to tune fuzzing without code changes.
//

import Foundation

enum TestEnv {
    /// True when running on CI (GitHub Actions, etc.)
    static var isCI: Bool {
        ProcessInfo.processInfo.environment["CI"] == "true"
    }

    /// Comma-separated list override:
    ///   DUNGEON_FUZZ_SEEDS="1,7,13,21"
    static var fuzzSeeds: [UInt64] {
        if let raw = ProcessInfo.processInfo.environment["DUNGEON_FUZZ_SEEDS"],
           !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return raw.split(separator: ",")
                .compactMap { UInt64($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
        // Default: lighter on CI, broader locally
        return isCI ? [1, 7, 33] : [1, 7, 13, 21, 33, 55, 89]
    }

    /// Number of random (start,goal) pairs per map in pathfinding fuzz.
    /// Override with: DUNGEON_FUZZ_PAIRS=NN
    static var fuzzPairs: Int {
        if let s = ProcessInfo.processInfo.environment["DUNGEON_FUZZ_PAIRS"],
           let n = Int(s) {
            return max(1, n)
        }
        return isCI ? 10 : 30
    }
}
