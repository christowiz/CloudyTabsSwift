//
//  ReadingListReader.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import Foundation
import Darwin

class ReadingListReader {
    
    func syncedBookmarksFile() -> String {
        // Get the real user home directory, not the sandbox container
        var realHome: String
        
        // Try to get real home directory from system
        if let passwd = getpwuid(getuid()) {
            realHome = String(cString: passwd.pointee.pw_dir)
        } else {
            // Fallback: try to get from environment or use NSHomeDirectory
            realHome = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            // If it's a container path, try to extract the real username
            if realHome.contains("/Containers/") {
                // Extract username from container path or use current user
                let username = NSUserName()
                realHome = "/Users/\(username)"
            }
        }
        let safariPath = (realHome as NSString).appendingPathComponent("Library/Safari")
        return (safariPath as NSString).appendingPathComponent("Bookmarks.plist")
    }
    
    func fetchReadingListItems(completionHandler: @escaping ([[String: Any]]?) -> Void) {
        DispatchQueue.global(qos: .default).async {
            let readingListItems = self.readingListBookmarks()
            completionHandler(readingListItems)
        }
    }
    
    func fetchReadingListModificationDate(completionHandler: @escaping (Date?) -> Void) {
        DispatchQueue.global(qos: .default).async {
            let modificationDate = self.syncedBookmarksModificationDate()
            completionHandler(modificationDate)
        }
    }
    
    // MARK: - Private
    
    private func readingListBookmarks() -> [[String: Any]]? {
        guard let syncedBookmarksDictionary = NSDictionary(contentsOfFile: syncedBookmarksFile()) as? [String: Any],
              let bookmarks = syncedBookmarksDictionary["Children"] as? [[String: Any]] else {
            return nil
        }
        
        let readingList = bookmarks.first { ($0["Title"] as? String) == "com.apple.ReadingList" }
        
        guard let readingListChildren = readingList?["Children"] as? [[String: Any]] else {
            return nil
        }
        
        return readingListChildren
    }
    
    private func syncedBookmarksModificationDate() -> Date? {
        let fileURL = URL(fileURLWithPath: syncedBookmarksFile())
        var modificationDate: AnyObject?
        try? (fileURL as NSURL).getResourceValue(&modificationDate, forKey: .contentModificationDateKey)
        return modificationDate as? Date
    }
}
