//
//  TileCodec.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

enum TileCodec {
    // Map Tile -> 2-bit
    @inline(__always) static func code(_ t: Tile) -> UInt8 {
        switch t {
        case .wall:  return 0
        case .floor: return 1
        case .door:  return 2
        }
    }
    // 2-bit -> Tile
    @inline(__always) static func tile(_ code: UInt8) -> Tile {
        switch code & 0b11 {
        case 0: return .wall
        case 1: return .floor
        case 2: return .door
        default: return .wall
        }
    }

    /// Pack tiles (row-major) into Base64 (2 bits per tile).
    static func packBase64(_ tiles: [Tile]) -> String {
        var out = [UInt8]()
        out.reserveCapacity((tiles.count + 3) / 4)
        var acc: UInt8 = 0
        var n: Int = 0
        for t in tiles {
            acc |= (code(t) & 0b11) << (n * 2)
            n += 1
            if n == 4 {
                out.append(acc); acc = 0; n = 0
            }
        }
        if n > 0 { out.append(acc) }
        return Data(out).base64EncodedString()
    }

    /// Unpack Base64 into tiles (expects `count` tiles).
    static func unpackBase64(_ s: String, count: Int) -> [Tile]? {
        guard let data = Data(base64Encoded: s) else { return nil }
        var tiles = [Tile](); tiles.reserveCapacity(count)
        var produced = 0
        for byte in data {
            for shift in 0..<4 {
                if produced == count { return tiles }
                let bits = (byte >> (shift * 2)) & 0b11
                tiles.append(tile(bits))
                produced += 1
            }
        }
        return produced == count ? tiles : nil
    }
}
