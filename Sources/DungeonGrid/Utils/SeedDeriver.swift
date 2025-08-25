//
//  SeedDeriver.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  Deterministically derive per-step seeds from a base seed + a string label.
//  Avoids magic constants while keeping runs fully reproducible.
//

public enum SeedDeriver {
    /// 64-bit FNV-1a over UTF-8 bytes (simple, stable)
    @inline(__always)
    private static func hash64(_ s: String) -> UInt64 {
        var x: UInt64 = 0xcbf29ce484222325 // FNV offset basis
        let prime: UInt64 = 0x00000100000001B3
        for b in s.utf8 { x ^= UInt64(b); x &*= prime }
        return x
    }

    /// One round of SplitMix-like avalanching (good diffusion for combined inputs).
    @inline(__always)
    private static func mix64(_ z: UInt64) -> UInt64 {
        var x = z &+ 0x9E3779B97F4A7C15
        x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
        x =  x ^ (x >> 31)
        return x
    }

    /// Derive a new seed from `base` and `label`.
    @inline(__always)
    public static func derive(_ base: UInt64, _ label: String) -> UInt64 {
        mix64(base &+ hash64(label))
    }
}
