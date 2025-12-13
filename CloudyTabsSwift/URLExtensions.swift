//
//  URLExtensions.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import Foundation

extension URL {
    
    static func decodeURL(_ urlString: String) -> URL? {
        // See dot point 4 under "NSURL Deprecations" in "Foundation Release Notes for OS X v10.11"
        if #available(macOS 10.11, *) {
            // Modern NSURL API available
            let urlData = urlString.data(using: .utf8)
            return urlData.flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
        } else {
            return legacyDecodeURL(urlString)
        }
    }
    
    private static func legacyDecodeURL(_ urlString: String) -> URL? {
        // Modern NSURL API not available, fall back to CoreFoundation implementation
        guard let urlData = urlString.data(using: .utf8) else { return nil }
        
        var urlRef: CFURL?
        urlData.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            urlRef = CFURLCreateWithBytes(
                kCFAllocatorDefault,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                urlData.count,
                CFStringEncoding(CFStringBuiltInEncodings.UTF8.rawValue),
                nil
            )
        }
        
        if urlRef == nil {
            // Fallback to using ISO Latin encoding
            urlData.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }
                urlRef = CFURLCreateWithBytes(
                    kCFAllocatorDefault,
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    urlData.count,
                    CFStringEncoding(CFStringBuiltInEncodings.isoLatin1.rawValue),
                    nil
                )
            }
        }
        
        return urlRef as URL?
    }
    
    static func privacyAllFilesSystemPreferencesURL() -> URL? {
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }
}
