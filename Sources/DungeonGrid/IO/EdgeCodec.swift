//
//  EdgeCodec.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

enum EdgeCodec {
    // Map EdgeType -> 2-bit
    @inline(__always) static func code(_ e: EdgeType) -> UInt8 {
        switch e {
        case .wall:   return 0
        case .open:   return 1
        case .door:   return 2
        case .locked: return 3
        }
    }
    @inline(__always) static func edge(_ code: UInt8) -> EdgeType {
        switch code & 0b11 {
        case 0: return .wall
        case 1: return .open
        case 2: return .door
        default: return .locked
        }
    }

    static func packBase64(_ edges: [EdgeType]) -> String {
        var out = [UInt8]()
        out.reserveCapacity((edges.count + 3) / 4)
        var acc: UInt8 = 0
        var n: Int = 0
        for e in edges {
            acc |= (code(e) & 0b11) << (n * 2)
            n += 1
            if n == 4 {
                out.append(acc); acc = 0; n = 0
            }
        }
        if n > 0 { out.append(acc) }
        return Data(out).base64EncodedString()
    }

    static func unpackBase64(_ s: String, count: Int) -> [EdgeType]? {
        guard let data = Data(base64Encoded: s) else { return nil }
        var arr = [EdgeType](); arr.reserveCapacity(count)
        var produced = 0
        for byte in data {
            for shift in 0..<4 {
                if produced == count { return arr }
                let bits = (byte >> (shift * 2)) & 0b11
                arr.append(edge(bits))
                produced += 1
            }
        }
        return produced == count ? arr : nil
    }
}
