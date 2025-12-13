//
//  DataExtensions.swift
//  CloudyTabsSwift
//
//  Based off NSData+Compression from CocoaGit
//  https://github.com/geoffgarside/cocoagit/blob/master/Source/Categories/NSData+Compression.m
//  Copyright 2008 ManicPanda.com. All rights reserved.
//

import Foundation
import zlib

extension Data {
    
    func zlibInflate() -> Data? {
        let length = self.count
        
        if length == 0 {
            return self
        }
        
        let halfLength = length / 2
        var decompressedLength = length + halfLength
        var decompressed = NSMutableData(length: decompressedLength)!
        var done = false
        
        return self.withUnsafeBytes { inputBytes in
            guard let inputBaseAddress = inputBytes.baseAddress else { return nil }
            
            var strm = z_stream()
            strm.next_in = UnsafeMutablePointer<Bytef>(mutating: inputBaseAddress.assumingMemoryBound(to: Bytef.self))
            strm.avail_in = uInt(length)
            strm.total_out = 0
            strm.zalloc = nil
            strm.zfree = nil
            
            if inflateInit_(&strm, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) != Z_OK {
                return nil
            }
            
            defer {
                inflateEnd(&strm)
            }
            
            while !done {
                // Make sure we have enough room and reset the lengths.
                if strm.total_out >= decompressedLength {
                    decompressedLength += halfLength
                    decompressed.increaseLength(by: halfLength)
                }
                
                let mutableBytes = decompressed.mutableBytes.assumingMemoryBound(to: Bytef.self)
                strm.next_out = mutableBytes.advanced(by: Int(strm.total_out))
                strm.avail_out = uInt(decompressedLength) - uInt(strm.total_out)
                
                // Inflate another chunk.
                let status = inflate(&strm, Z_SYNC_FLUSH)
                if status == Z_STREAM_END {
                    done = true
                } else if status != Z_OK {
                    return nil
                }
            }
            
            // Set real length.
            if done {
                decompressed.length = Int(strm.total_out)
                return decompressed as Data
            } else {
                return nil
            }
        }
    }
}
