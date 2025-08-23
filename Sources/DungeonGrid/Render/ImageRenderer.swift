//
//  ImageRenderer.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

public enum ImageRenderer {

    public struct Options: Sendable, Equatable {
        public var cellSize: Int = 6
        public var edgeThickness: Int = 1
        public var drawOpenEdges: Bool = false
        public var drawEdges: Bool = true
        public var drawGrid: Bool = false

        public init() {}

        public init(cellSize: Int = 6,
                    edgeThickness: Int = 1,
                    drawOpenEdges: Bool = false,
                    drawEdges: Bool = true,
                    drawGrid: Bool = false) {
            self.cellSize = max(1, cellSize)
            self.edgeThickness = max(1, edgeThickness)
            self.drawOpenEdges = drawOpenEdges
            self.drawEdges = drawEdges
            self.drawGrid = drawGrid
        }
    }

    public struct Overlays: Sendable {
        public var graph: RegionGraph? = nil
        public var themes: ThemeAssignment? = nil
        public var placements: [Placement] = []
        public var paths: [[Point]] = []   // ✅ NEW

        public init() {}

        public init(graph: RegionGraph? = nil,
                    themes: ThemeAssignment? = nil,
                    placements: [Placement] = [],
                    paths: [[Point]] = []) {   // ✅ NEW
            self.graph = graph
            self.themes = themes
            self.placements = placements
            self.paths = paths
        }
    }

    // MARK: - Public API

    /// Rasterize dungeon to an RGBA buffer (row-major, 8-bit per channel).
    public static func rasterize(_ d: Dungeon,
                                 options: Options = Options(),
                                 overlays: Overlays = Overlays()) -> (width: Int, height: Int, pixels: [UInt8]) {
        let W = d.grid.width, H = d.grid.height
        let s = max(1, options.cellSize)
        let ew = max(1, options.edgeThickness)

        let width = W * s + 1 // +1 so far-border edges can draw
        let height = H * s + 1
        var px = Array(repeating: UInt8(0), count: width * height * 4)

        // Base palette
        let wallC     = RGBA(26, 26, 26)
        let floorC    = RGBA(44, 44, 44)
        let doorTileC = RGBA(220, 180, 40)
        let entranceC = RGBA(60, 200, 90)
        let exitC     = RGBA(80, 200, 230)

        let openEdgeC   = RGBA(90, 90, 90)
        let doorEdgeC   = RGBA(240, 210, 60)
        let lockedEdgeC = RGBA(210, 60, 60)

        // Theme color (deterministic by theme name)
        func themeColor(name: String) -> RGBA {
            let h = fnv64(name)
            let r = UInt8((h >>  0) & 0xFF)
            let g = UInt8((h >> 16) & 0xFF)
            let b = UInt8((h >> 32) & 0xFF)
            return RGBA(r &+ 60, g &+ 60, b &+ 60, 255)
        }

        // Placement color (deterministic by kind)
        func placementColor(kind: String) -> RGBA {
            let h = fnv64(kind) ^ 0x9E3779B97F4A7C15
            return RGBA(UInt8((h >> 8) & 0xFF), UInt8((h >> 24) & 0xFF), UInt8((h >> 40) & 0xFF), 255)
        }

        // Region labels for theming
        let (labels, _, _, _) = Regions.labelCells(d)

        // Fill cells
        for y in 0..<H {
            for x in 0..<W {
                let base: RGBA = {
                    switch d.grid[x, y] {
                    case .wall:  return wallC
                    case .floor: return floorC
                    case .door:  return doorTileC
                    }
                }()
                var c = base
                // Theme tint: blend toward theme color for floor cells
                if d.grid[x, y] == .floor, let rid = labels[y * W + x],
                   let theme = overlays.themes?.regionToTheme[rid] {
                    let tc = themeColor(name: theme.name)
                    c = blend(base: base, tint: tc, alpha: 0.35)
                }
                fillRect(&px, width, height, x*s, y*s, s, s, c)
            }
        }

        // Draw edges on seams
        if options.drawEdges {
            // Vertical edges
            for y in 0..<H {
                for vx in 1...W {
                    let e = d.edges[vx: vx, vy: y]
                    let color: RGBA? = {
                        switch e {
                        case .open:   return options.drawOpenEdges ? openEdgeC : nil
                        case .door:   return doorEdgeC
                        case .locked: return lockedEdgeC
                        case .wall:   return nil
                        }
                    }()
                    if let c = color {
                        let xpix = vx*s
                        fillRect(&px, width, height, xpix, y*s, ew, s, c)
                    }
                }
            }
            // Horizontal edges
            for hy in 1...H {
                for x in 0..<W {
                    let e = d.edges[hx: x, hy: hy]
                    let color: RGBA? = {
                        switch e {
                        case .open:   return options.drawOpenEdges ? openEdgeC : nil
                        case .door:   return doorEdgeC
                        case .locked: return lockedEdgeC
                        case .wall:   return nil
                        }
                    }()
                    if let c = color {
                        let ypix = hy*s
                        fillRect(&px, width, height, x*s, ypix, s, ew, c)
                    }
                }
            }
        }

        // Entrance/Exit markers (small dots)
        if let spt = d.entrance {
            drawDot(&px, width, height, spt.x * s + s/2, spt.y * s + s/2, max(1, s/3), entranceC)
        }
        if let tpt = d.exit {
            drawDot(&px, width, height, tpt.x * s + s/2, tpt.y * s + s/2, max(1, s/3), exitC)
        }
        
        // Paths overlay (magenta-like dots)
        let pathC = RGBA(250, 80, 200)
        for path in overlays.paths {
            for p in path {
                drawDot(&px, width, height, p.x * s + s/2, p.y * s + s/2, max(1, s/4), pathC)
            }
        }

        // Placements
        for p in overlays.placements {
            let col = placementColor(kind: p.kind)
            drawDot(&px, width, height, p.position.x * s + s/2, p.position.y * s + s/2, max(1, s/3), col)
        }

        // Optional grid
        if options.drawGrid && s >= 4 {
            let gc = RGBA(0, 0, 0, 60)
            for gx in 0...W { vline(&px, width, height, gx*s, 0, height-1, gc) }
            for gy in 0...H { hline(&px, width, height, 0, width-1, gy*s, gc) }
        }

        return (width, height, px)
    }

    /// Return PNG data when CoreGraphics/ImageIO are available; nil otherwise.
    public static func pngData(_ d: Dungeon,
                               options: Options = Options(),
                               overlays: Overlays = Overlays()) -> Data? {
        #if canImport(CoreGraphics) && canImport(ImageIO)
        let (w, h, buf) = rasterize(d, options: options, overlays: overlays)
        return pngFromRGBA(width: w, height: h, rgba: buf)
        #else
        return nil
        #endif
    }

    /// Return binary PPM (P6) data (always available).
    public static func ppmData(_ d: Dungeon,
                               options: Options = Options(),
                               overlays: Overlays = Overlays()) -> Data {
        let (w, h, buf) = rasterize(d, options: options, overlays: overlays)
        // Convert RGBA → RGB by dropping alpha
        var body = Data(capacity: w * h * 3)
        body.withUnsafeMutableBytes { raw in
            guard var dst = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            var i = 0
            while i < buf.count {
                dst.pointee = buf[i];     dst = dst.advanced(by: 1) // R
                dst.pointee = buf[i + 1]; dst = dst.advanced(by: 1) // G
                dst.pointee = buf[i + 2]; dst = dst.advanced(by: 1) // B
                i += 4
            }
        }
        var header = "P6\n\(w) \(h)\n255\n".data(using: .ascii)!
        header.append(body)
        return header
    }

    // MARK: - Low-level drawing

    @inline(__always)
    private static func idx(_ x: Int, _ y: Int, _ width: Int) -> Int { (y * width + x) * 4 }

    private static func put(_ px: inout [UInt8], _ width: Int, _ height: Int, _ x: Int, _ y: Int, _ c: RGBA) {
        if x < 0 || y < 0 || x >= width || y >= height { return }
        let i = idx(x, y, width)
        px[i] = c.r; px[i+1] = c.g; px[i+2] = c.b; px[i+3] = c.a
    }

    private static func fillRect(_ px: inout [UInt8], _ width: Int, _ height: Int,
                                 _ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: RGBA) {
        let x0 = max(0, x), y0 = max(0, y)
        let x1 = min(width, x + w), y1 = min(height, y + h)
        var yy = y0
        while yy < y1 {
            var xx = x0
            let base = yy * width
            while xx < x1 {
                let i = (base + xx) * 4
                px[i] = c.r; px[i+1] = c.g; px[i+2] = c.b; px[i+3] = c.a
                xx += 1
            }
            yy += 1
        }
    }

    private static func drawDot(_ px: inout [UInt8], _ width: Int, _ height: Int,
                                _ cx: Int, _ cy: Int, _ radius: Int, _ c: RGBA) {
        let r2 = radius * radius
        let x0 = cx - radius, x1 = cx + radius
        let y0 = cy - radius, y1 = cy + radius
        var y = y0
        while y <= y1 {
            var x = x0
            while x <= x1 {
                let dx = x - cx, dy = y - cy
                if dx*dx + dy*dy <= r2 { put(&px, width, height, x, y, c) }
                x += 1
            }
            y += 1
        }
    }

    private static func vline(_ px: inout [UInt8], _ width: Int, _ height: Int,
                              _ x: Int, _ y0: Int, _ y1: Int, _ c: RGBA) {
        let yy0 = max(0, min(y0, y1)), yy1 = min(height-1, max(y0, y1))
        if x < 0 || x >= width { return }
        var y = yy0
        while y <= yy1 { put(&px, width, height, x, y, c); y += 1 }
    }

    private static func hline(_ px: inout [UInt8], _ width: Int, _ height: Int,
                              _ x0: Int, _ x1: Int, _ y: Int, _ c: RGBA) {
        let xx0 = max(0, min(x0, x1)), xx1 = min(width-1, max(x0, x1))
        if y < 0 || y >= height { return }
        var x = xx0
        while x <= xx1 { put(&px, width, height, x, y, c); x += 1 }
    }

    // MARK: - Utilities

    private static func fnv64(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h ^= UInt64(b); h &*= 0x00000100000001B3 }
        return h
    }

    private static func clampU8(_ x: Double) -> UInt8 {
        if x <= 0 { return 0 }
        if x >= 255 { return 255 }
        return UInt8(x.rounded())
    }

    private static func blend(base: RGBA, tint: RGBA, alpha: Double) -> RGBA {
        let t = max(0.0, min(1.0, alpha))
        @inline(__always) func mix(_ u: UInt8, _ v: UInt8) -> UInt8 {
            let bu = Double(u), tv = Double(v)
            return clampU8(bu * (1.0 - t) + tv * t)
        }
        return RGBA(mix(base.r, tint.r),
                    mix(base.g, tint.g),
                    mix(base.b, tint.b),
                    255)
    }

    #if canImport(CoreGraphics) && canImport(ImageIO)
    private static func pngFromRGBA(width: Int, height: Int, rgba: [UInt8]) -> Data? {
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let info = CGBitmapInfo.byteOrderDefault.union(.init(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
        guard let img = CGImage(width: width, height: height,
                                bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width*4,
                                space: cs, bitmapInfo: info,
                                provider: provider, decode: nil,
                                shouldInterpolate: false, intent: .defaultIntent) else { return nil }

        let out = NSMutableData()
        #if canImport(UniformTypeIdentifiers)
        let type = UTType.png.identifier as CFString
        #else
        let type = "public.png" as CFString
        #endif
        guard let dest = CGImageDestinationCreateWithData(out, type, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, img, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
    #endif
}
