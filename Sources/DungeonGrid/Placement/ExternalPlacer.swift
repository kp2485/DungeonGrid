//
//  ExternalPlacer.swift
//  DungeonGrid
//
//  Deterministic external placement with footprint + group support.
//  - Fully validates .single / .rect / .mask footprints
//  - Enforces policy constraints (region class, door tiles, spacing, LOS, etc.)
//  - Solves groups together (sameRegion, min/max anchor distance, sameTheme)
//

import Foundation

public enum ExternalPlacer {
    // Result type used by tests: they only read `placements` and fields below.
    public struct Result: Equatable, Sendable {
        public let placements: [Placement]
        public init(placements: [Placement]) { self.placements = placements }
    }

    public struct Placement: Equatable, Sendable {
        public let id: String
        public let kind: String
        public let position: Point           // anchor
        public let region: RegionID?         // resolved from labels
        public init(id: String, kind: String, position: Point, region: RegionID?) {
            self.id = id; self.kind = kind; self.position = position; self.region = region
        }
    }

    // MARK: - Public entry point (no groups overload)

    public static func place(
        in d: Dungeon,
        index: DungeonIndex,
        themes: ThemeAssignment?,
        seed: UInt64,
        items: [AnyPlaceable]
    ) -> Result {
        return place(in: d, index: index, themes: themes, seed: seed, items: items, groups: [])
    }

    // MARK: - Public entry point (with groups)

    public static func place(
        in d: Dungeon,
        index: DungeonIndex,
        themes: ThemeAssignment?,
        seed: UInt64,
        items: [AnyPlaceable],
        groups: [PlacementGroup]
    ) -> Result {

        // --- Precompute cheap lookups ---
        let w = d.grid.width, h = d.grid.height
        @inline(__always) func li(_ x: Int, _ y: Int) -> Int { y * w + x }

        let doorSet: Set<Int> = Set(d.doors.map { li($0.x, $0.y) })
        let (labels, kindsByID, lw, _) = Regions.labelCells(d)
        precondition(lw == w, "label width mismatch")
        let graph = index.graph
        let nodeStats = RegionAnalysis.computeStats(dungeon: d, graph: graph).nodes

        // Theme lookup (optional)
        let themeByRegion: [RegionID: Theme] = themes?.regionToTheme ?? [:]

        // Deterministic scan order of all passable cells
        var passableAnchors: [Point] = []
        passableAnchors.reserveCapacity(w * h / 2)
        for y in 0..<h {
            for x in 0..<w where d.grid[x, y].isPassable {
                passableAnchors.append(Point(x, y))
            }
        }

        // Occupancy tracks every TILE used by any placed footprint
        var occupied = Set<Int>()
        // Also track anchors to enforce minSpacing by anchor distance (Manhattan)
        var placedAnchors: [Point] = []
        // And track per-anchor region for quick checks
        var anchorRegion: [Int: RegionID?] = [:] // li -> RegionID?

        // Helper: region & class checks
        @inline(__always)
        func regionID(of p: Point) -> RegionID? {
            if let r = anchorRegion[li(p.x, p.y)] { return r }
            let r = labels[p.y * w + p.x]
            anchorRegion[li(p.x, p.y)] = r
            return r
        }
        @inline(__always)
        func isRoomRegion(_ rid: RegionID?) -> Bool {
            guard let rid, let k = kindsByID[rid] else { return false }
            if case .room = k { return true }
            return false
        }
        @inline(__always)
        func inRegionClass(_ rid: RegionID?, policy: PlacementPolicy) -> Bool {
            switch policy.regionClass {
            case .roomsOnly:
                return isRoomRegion(rid)
            case .corridorsOnly:
                return !isRoomRegion(rid)
            case .any:
                return true
            case .junctions(let minDegree):
                guard let rid = rid, let ns = nodeStats[rid] else { return false }
                return ns.degree >= minDegree
            case .deadEnds:
                guard let rid = rid, let ns = nodeStats[rid] else { return false }
                return ns.isDeadEnd
            case .farFromEntrance(let minHops):
                guard let rid = rid, let ns = nodeStats[rid] else { return false }
                let d = ns.distanceFromEntrance ?? Int.max
                return d >= minHops
            case .nearEntrance(let maxHops):
                guard let rid = rid, let ns = nodeStats[rid] else { return false }
                if let d = ns.distanceFromEntrance { return d <= maxHops } else { return false }
            case .perimeter:
                guard let rid = rid, let node = graph.nodes[rid] else { return false }
                let r = node.bbox
                return r.x == 0 || r.y == 0 || (r.x + r.width) == w || (r.y + r.height) == h
            case .core:
                guard let rid = rid, let node = graph.nodes[rid] else { return false }
                let r = node.bbox
                let touches = r.x == 0 || r.y == 0 || (r.x + r.width) == w || (r.y + r.height) == h
                return !touches
            }
        }

        // Helper: expand footprint → absolute tiles
        func tiles(for anchor: Point, footprint: Footprint) -> [Point] {
            switch footprint {
            case .single:
                return [anchor]
            case .rect(let width, let height):
                var out: [Point] = []
                out.reserveCapacity(width * height)
                for dy in 0..<height {
                    for dx in 0..<width {
                        out.append(Point(anchor.x + dx, anchor.y + dy))
                    }
                }
                return out
            case .mask(let offsets):
                return offsets.map { Point(anchor.x + $0.x, anchor.y + $0.y) }
            }
        }

        // Helper: LOS guard (used only when requested)
        @inline(__always)
        func violatesLOS(from s: Point, to t: Point, doorsTransparent: Bool) -> Bool {
            Visibility.hasLineOfSight(in: d, from: s, to: t,
                                      policy: .init(doorTransparent: doorsTransparent))
        }

        // Helper: per-item validity at a given anchor (without spacing/occupancy)
        func basicAnchorOK(_ item: AnyPlaceable, _ anchor: Point) -> (ok: Bool, tiles: [Point], rid: RegionID?) {
            // Region class
            let rid = regionID(of: anchor)
            guard inRegionClass(rid, policy: item.policy) else { return (false, [], rid) }

            // Footprint tiles in-bounds, passable, and (optionally) non-door
            let pts = tiles(for: anchor, footprint: item.footprint)
            for p in pts {
                if p.x < 0 || p.y < 0 || p.x >= w || p.y >= h { return (false, [], rid) }
                if !d.grid[p.x, p.y].isPassable { return (false, [], rid) }
                if item.policy.excludeDoorTiles && doorSet.contains(li(p.x, p.y)) { return (false, [], rid) }
            }

            // Entrance distance + LOS (if configured)
            if let s = d.entrance {
                if let md = item.policy.minDistanceFromEntrance {
                    let m = abs(anchor.x - s.x) + abs(anchor.y - s.y)
                    if m < md { return (false, [], rid) }
                }
                if item.policy.avoidLOSFromEntrance {
                    if violatesLOS(from: s, to: anchor, doorsTransparent: item.policy.doorsTransparentForLOS) {
                        return (false, [], rid)
                    }
                }
            }
            return (true, pts, rid)
        }

        // Helper: global spacing/occupancy check (tiles vs. occupied; anchor vs. placedAnchors)
        func fitsGlobal(_ item: AnyPlaceable, _ pts: [Point], _ anchor: Point) -> Bool {
            // Occupancy
            for p in pts { if occupied.contains(li(p.x, p.y)) { return false } }
            // Min spacing by anchor Manhattan distance (conservative & matches tests)
            let minSp = max(0, item.policy.minSpacing)
            if minSp > 0 {
                for q in placedAnchors {
                    let m = abs(anchor.x - q.x) + abs(anchor.y - q.y)
                    if m < minSp { return false }
                }
            }
            return true
        }

        // Helper: commit placement
        @inline(__always)
        func commit(_ item: AnyPlaceable, _ anchor: Point, _ pts: [Point], _ rid: RegionID?, into out: inout [Placement]) {
            for p in pts { occupied.insert(li(p.x, p.y)) }
            placedAnchors.append(anchor)
            out.append(Placement(id: item.id as! String, kind: item.kind, position: anchor, region: rid))
        }

        // Deterministic candidate list per item (scanline)
        func candidates(for item: AnyPlaceable) -> [Stamp] {
            var cands: [Stamp] = []
            cands.reserveCapacity(128)
            for a in passableAnchors {
                let (ok, pts, rid) = basicAnchorOK(item, a)
                if ok { cands.append((a, pts, rid)) } // positional → labels come from `Stamp` (a, tiles, rid)
            }
            return cands
        }

        // --- Partition into groups and singles ---
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        // Convert group member IDs (AnyHashable) → [String] safely
        func toStringIDs(_ anyIDs: [AnyHashable]) -> [String] {
            anyIDs.compactMap { $0 as? String }
        }

        let groupedIDStrings: Set<String> = Set(groups.flatMap { toStringIDs($0.memberIDs) })
        let singleItems = items.filter { !groupedIDStrings.contains($0.id as! String) }

        var placements: [Placement] = []
        placements.reserveCapacity(items.count)

        // --- Solve each group deterministically with backtracking ---
        func solveGroup(_ g: PlacementGroup) {
            let memberIDs: [String] = toStringIDs(g.memberIDs)
            if memberIDs.isEmpty { return }

            let memItems: [AnyPlaceable] = memberIDs.compactMap { byID[$0] }
            if memItems.isEmpty { return }

            // Precompute per-member candidates
            let perMember: [[Stamp]] = memItems.map { candidates(for: $0) }
            if perMember.contains(where: { $0.isEmpty }) {
                // At least one member has no candidates given current world/policy; skip group gracefully.
                return
            }

            // Backtracking state
            var chosen: [(idx: Int, a: Point, tiles: [Point], rid: RegionID?)] = []

            // Theme constraint helper
            @inline(__always)
            func themesOK() -> Bool {
                guard g.sameTheme, let first = chosen.first else { return true }
                let t0 = first.rid.flatMap { themeByRegion[$0] }
                for c in chosen.dropFirst() {
                    let t = c.rid.flatMap { themeByRegion[$0] }
                    if t?.name != t0?.name { return false }
                }
                return true
            }

            func regionOK(_ nextRID: RegionID?) -> Bool {
                guard g.sameRegion, let r0 = chosen.first?.rid else { return true }
                return nextRID == r0
            }

            func distOK(_ anchor: Point) -> Bool {
                let mn = g.minAnchorDistance ?? Int.min
                let mx = g.maxAnchorDistance ?? Int.max
                for c in chosen {
                    let m = abs(anchor.x - c.a.x) + abs(anchor.y - c.a.y)
                    if m < mn || m > mx { return false }
                }
                return true
            }

            var solved = false
            func dfs(_ i: Int) {
                if solved { return }
                if i == memItems.count {
                    // All chosen; commit
                    for (k, c) in chosen.enumerated() {
                        commit(memItems[k], c.a, c.tiles, c.rid, into: &placements)
                    }
                    solved = true
                    return
                }
                let it = memItems[i]
                for cand in perMember[i] {
                    // Group filters
                    if !regionOK(cand.rid) { continue }
                    if !distOK(cand.a) { continue }
                    // Global occupancy/spacing *including* already chosen group anchors
                    var ok = true
                    for p in cand.tiles { if occupied.contains(li(p.x, p.y)) { ok = false; break } }
                    if !ok { continue }
                    if !fitsGlobal(it, cand.tiles, cand.a) { continue }
                    // Also enforce minSpacing against already-chosen group anchors
                    let minSp = max(0, it.policy.minSpacing)
                    if minSp > 0 {
                        for other in chosen {
                            let m = abs(cand.a.x - other.a.x) + abs(cand.a.y - other.a.y)
                            if m < minSp { ok = false; break }
                        }
                        if !ok { continue }
                    }

                    chosen.append((i, cand.a, cand.tiles, cand.rid))
                    if themesOK() {
                        dfs(i + 1)
                    }
                    if solved { return }
                    _ = chosen.popLast()
                }
            }

            dfs(0)
        }

        // Place groups first (to give them room)
        for g in groups {
            solveGroup(g)
        }

        // --- Place singles deterministically ---
        for it in singleItems {
            let cands = candidates(for: it)
            if cands.isEmpty { continue }
            var placed = false
            for cand in cands {
                if fitsGlobal(it, cand.tiles, cand.a) {
                    commit(it, cand.a, cand.tiles, cand.rid, into: &placements)
                    placed = true
                    break
                }
            }
            if !placed {
                // Couldn’t satisfy spacing/occupancy right now; skip gracefully.
                continue
            }
        }

        return Result(placements: placements)
    }
}
