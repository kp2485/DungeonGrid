//
//  RNG.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

/// SplitMix64: small, fast, deterministic RNG suitable for procedural gen.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { self.state = seed &+ 0x9E3779B97F4A7C15 }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    @inline(__always)
    public mutating func int(in range: ClosedRange<Int>) -> Int {
        precondition(range.lowerBound <= range.upperBound)
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    @inline(__always)
    public mutating func bool(_ pTrue: Double = 0.5) -> Bool {
        let x = Double(next() >> 11) / Double(1 << 53)
        return x < pTrue
    }
}
