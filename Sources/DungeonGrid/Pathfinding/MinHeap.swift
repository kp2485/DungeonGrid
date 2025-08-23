//
//  MinHeap.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

/// Tiny binary min-heap for (priority, nodeIndex). Tailored for A*.
/// Stable enough for internal use; not exposed publicly.
struct MinHeap {
    private var p: [Int] = []  // priorities (fScore)
    private var v: [Int] = []  // node indices

    var isEmpty: Bool { p.isEmpty }
    mutating func removeAll(keepingCapacity keep: Bool = false) { p.removeAll(keepingCapacity: keep); v.removeAll(keepingCapacity: keep) }

    mutating func push(priority: Int, value: Int) {
        p.append(priority); v.append(value)
        siftUp(from: p.count - 1)
    }

    mutating func pop() -> (priority: Int, value: Int)? {
        guard !p.isEmpty else { return nil }
        let last = p.count - 1
        swapAt(0, last)
        let out = (p.removeLast(), v.removeLast())
        if !p.isEmpty { siftDown(from: 0) }
        return out
    }

    // MARK: - Heap helpers
    private mutating func swapAt(_ i: Int, _ j: Int) {
        (p[i], p[j]) = (p[j], p[i])
        (v[i], v[j]) = (v[j], v[i])
    }
    private mutating func siftUp(from i0: Int) {
        var i = i0
        while i > 0 {
            let parent = (i - 1) >> 1
            if p[i] < p[parent] { swapAt(i, parent); i = parent } else { break }
        }
    }
    private mutating func siftDown(from i0: Int) {
        var i = i0
        while true {
            let l = (i << 1) + 1
            if l >= p.count { break }
            var m = l
            let r = l + 1
            if r < p.count, p[r] < p[l] { m = r }
            if p[m] < p[i] { swapAt(i, m); i = m } else { break }
        }
    }
}