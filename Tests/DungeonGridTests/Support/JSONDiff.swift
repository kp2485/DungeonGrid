//
//  JSONDiff.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  Minimal JSON diff to pinpoint the first mismatch path and values.
//

import Foundation

/// Return a human-readable description of the first difference between two JSON payloads.
/// Both inputs may be Data or Any (Dictionary/Array/Scalar).
func diffJSONData(_ a: Data, _ b: Data) -> String {
    let aObj = (try? JSONSerialization.jsonObject(with: a)) ?? NSNull()
    let bObj = (try? JSONSerialization.jsonObject(with: b)) ?? NSNull()
    return diffJSONObjects(aObj, bObj)
}

func diffJSONObjects(_ a: Any, _ b: Any, path: String = "$") -> String {
    // NSNull normalization
    if a is NSNull, b is NSNull { return "equal" }
    // Type mismatch
    switch (a, b) {
    case let (ad as [String: Any], bd as [String: Any]):
        let aKeys = Set(ad.keys), bKeys = Set(bd.keys)
        if aKeys != bKeys {
            let onlyA = aKeys.subtracting(bKeys).sorted()
            let onlyB = bKeys.subtracting(aKeys).sorted()
            var parts: [String] = []
            if !onlyA.isEmpty { parts.append("keys only in A: \(onlyA)") }
            if !onlyB.isEmpty { parts.append("keys only in B: \(onlyB)") }
            return "\(path): object keys differ (\(parts.joined(separator: "; ")))"
        }
        for k in aKeys.sorted() {
            let sub = diffJSONObjects(ad[k] as Any, bd[k] as Any, path: "\(path).\(k)")
            if sub != "equal" { return sub }
        }
        return "equal"

    case let (aa as [Any], bb as [Any]):
        if aa.count != bb.count {
            return "\(path): array length differs (A=\(aa.count) B=\(bb.count))"
        }
        for i in 0..<aa.count {
            let sub = diffJSONObjects(aa[i], bb[i], path: "\(path)[\(i)]")
            if sub != "equal" { return sub }
        }
        return "equal"

    case let (an as NSNumber, bn as NSNumber):
        // NSNumber bridges Bool/Int/Double — compare both type-ish and value.
        if CFGetTypeID(an) != CFGetTypeID(bn) {
            // Still allow numeric equality despite different wrappers.
            if an == bn { return "equal" }
            return "\(path): number type differs (A=\(an) B=\(bn))"
        }
        if an != bn {
            return "\(path): number differs (A=\(an) B=\(bn))"
        }
        return "equal"

    case let (as1 as String, bs1 as String):
        if as1 != bs1 {
            return "\(path): string differs (A=\(String(describing: as1)) B=\(String(describing: bs1)))"
        }
        return "equal"

    case (_ as NSNull, _), (_, _ as NSNull):
        if String(describing: a) == String(describing: b) { return "equal" }
        return "\(path): null vs non-null (A=\(a) B=\(b))"

    default:
        let sa = String(describing: a)
        let sb = String(describing: b)
        if sa != sb { return "\(path): value differs (A=\(sa) B=\(sb))" }
        return "equal"
    }
}
