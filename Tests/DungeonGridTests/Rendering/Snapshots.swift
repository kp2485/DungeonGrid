//
//  Snapshots.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

/// Preferred output directory:
/// 1) DUNGEONGRID_SNAPSHOT_DIR (if set)
/// 2) ~/Downloads/DungeonGridSnapshots
/// 3) NSTemporaryDirectory()
private func snapshotDirectory() -> URL {
    let fm = FileManager.default
    if let custom = ProcessInfo.processInfo.environment["DUNGEONGRID_SNAPSHOT_DIR"], !custom.isEmpty {
        let url = URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    if let downloads = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first {
        let url = downloads.appendingPathComponent("DungeonGridSnapshots", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
}

@discardableResult
func writePNGSnapshot(_ data: Data, name: String = "DungeonGrid.png") -> URL? {
    let dir = snapshotDirectory()
    let url = dir.appendingPathComponent(name)
    do {
        try data.write(to: url, options: .atomic)
        print("🖼 PNG snapshot → \(url.path)")
        print("   file://\(url.path)") // clickable in Xcode console
        return url
    } catch {
        print("⚠️ Failed to write PNG: \(error)")
        return nil
    }
}

@discardableResult
func writePPMSnapshot(_ data: Data, name: String = "DungeonGrid.ppm") -> URL? {
    let dir = snapshotDirectory()
    let url = dir.appendingPathComponent(name)
    do {
        try data.write(to: url, options: .atomic)
        print("🖼 PPM snapshot → \(url.path)")
        print("   file://\(url.path)")
        return url
    } catch {
        print("⚠️ Failed to write PPM: \(error)")
        return nil
    }
}
