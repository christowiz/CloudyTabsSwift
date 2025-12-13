//
//  CloudTabsDBReader.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import Foundation
import FMDB
import Darwin

class CloudTabsDBReader {
    
    private var cloudTabsDatabase: FMDatabase?
    
    func cloudTabsDBFile() -> String {
        let basePath = CloudTabsDBReader.safariLibraryDirectory().appendingPathComponent("CloudTabs.db")
        
        // Resolve symbolic link if it exists (Safari may use a symlink)
        let fileManager = FileManager.default
        var resolvedPath = basePath
        
        // Check if it's a symlink and resolve it
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: basePath, isDirectory: &isDirectory) {
            do {
                let destination = try fileManager.destinationOfSymbolicLink(atPath: basePath)
                // It's a symlink, resolve it
                if destination.hasPrefix("/") {
                    // Absolute path
                    resolvedPath = destination
                } else {
                    // Relative path - resolve relative to the symlink's directory
                    let symlinkDir = (basePath as NSString).deletingLastPathComponent
                    resolvedPath = (symlinkDir as NSString).appendingPathComponent(destination)
                }
                print("DEBUG: CloudTabs.db is a symlink")
                print("DEBUG: Original path: \(basePath)")
                print("DEBUG: Resolved path: \(resolvedPath)")
            } catch {
                // Not a symlink or can't resolve
                print("DEBUG: CloudTabs.db path: \(resolvedPath)")
            }
        } else {
            print("DEBUG: CloudTabs.db does not exist at: \(basePath)")
        }
        
        return resolvedPath
    }
    
    func permissionsToReadFile() -> Bool {
        let filePath = cloudTabsDBFile()
        let fileExists = FileManager.default.fileExists(atPath: filePath)
        
        if !fileExists {
            print("DEBUG: CloudTabs.db file does not exist at: \(filePath)")
            return false
        }
        
        // Check file permissions
        var _: ObjCBool = false
        let fileManager = FileManager.default
        
        if fileManager.isReadableFile(atPath: filePath) {
            // Try to actually read the file
            if let _ = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                return true
            } else {
                print("DEBUG: File exists but cannot be read - likely Full Disk Access not granted")
                print("DEBUG: Go to: System Settings → Privacy & Security → Full Disk Access")
                print("DEBUG: Add CloudyTabsSwift.app and enable it, then restart the app")
                return false
            }
        } else {
            print("DEBUG: File is not readable - Full Disk Access required")
            print("DEBUG: Path: \(filePath)")
            return false
        }
    }
    
    func fetchTabData(completionHandler: @escaping ([[String: Any]]?) -> Void) {
        DispatchQueue.global(qos: .default).async {
            var items: [[String: Any]] = []
            
            guard let deviceIDs = self.deviceIDs else {
                completionHandler(nil)
                return
            }
            
            for deviceID in deviceIDs {
                guard let name = self.deviceName(forID: deviceID) else {
                    continue
                }
                
                var dictionary: [String: Any] = [:]
                dictionary["DeviceName"] = name
                dictionary["Tabs"] = self.tabs(forDeviceID: deviceID) ?? []
                
                items.append(dictionary)
            }
            
            if items.count > 0 {
                completionHandler(items)
            } else {
                completionHandler(nil)
            }
        }
    }
    
    func fetchDatabaseModificationDate(completionHandler: @escaping (Date?) -> Void) {
        DispatchQueue.global(qos: .default).async {
            completionHandler(self.modificationDate)
        }
    }
    
    // MARK: - Private
    
    private static func safariLibraryDirectory() -> String {
        // Get the real user home directory, not the sandbox container
        // NSHomeDirectory() returns container path when sandboxed, so we use getpwuid
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
        return safariPath
    }
    
    private var database: FMDatabase? {
        if cloudTabsDatabase == nil {
            let dbPath = cloudTabsDBFile()
            
            // Check if file exists
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: dbPath) else {
                print("DEBUG: ❌ CloudTabs.db does not exist at: \(dbPath)")
                print("DEBUG: Check if the path is correct and Safari has synced iCloud tabs")
                return nil
            }
            
            // Test read access - FileHandle may fail even with Full Disk Access
            // So we'll test with Data(contentsOf:) which is more reliable
            print("DEBUG: Testing file access...")
            do {
                // Try to read file attributes
                let attributes = try fileManager.attributesOfItem(atPath: dbPath)
                print("DEBUG: ✅ File attributes readable")
                
                // Try to read a small portion of the file to verify access
                // This is more reliable than FileHandle for Full Disk Access
                if let _ = try? Data(contentsOf: URL(fileURLWithPath: dbPath), options: .mappedIfSafe) {
                    print("DEBUG: ✅ File content readable - Full Disk Access is working!")
                } else {
                    print("DEBUG: ⚠️ Cannot read file content directly, but will try copying to temp location")
                    // Continue anyway - we'll copy to temp location
                }
            } catch {
                print("DEBUG: ❌ Cannot access file: \(error.localizedDescription)")
                print("DEBUG: Full Disk Access may not be working")
                print("DEBUG: App path: \(Bundle.main.bundlePath)")
                print("DEBUG: Error details: \(error)")
                // Continue anyway - try copying to temp location
            }
            
            // SQLite needs to create lock files (.db-wal, .db-shm) in the same directory
            // Even with Full Disk Access, we can't write to Safari's container directory
            // Solution: Read the file content and write it to a temporary location
            
            // Use system temp directory, not sandbox container temp
            let tempDir = "/tmp"
            let tempDBPath = (tempDir as NSString).appendingPathComponent("CloudTabs_\(UUID().uuidString).db")
            
            print("DEBUG: Reading database and writing to temporary location for SQLite access...")
            print("DEBUG: Source path: \(dbPath)")
            print("DEBUG: Destination path: \(tempDBPath)")
            
            do {
                // Remove temp file if it exists
                if fileManager.fileExists(atPath: tempDBPath) {
                    try fileManager.removeItem(atPath: tempDBPath)
                }
                
                // Try reading with different methods
                print("DEBUG: Attempting to read database file...")
                
                // Method 1: Try Data(contentsOf:) with file URL
                let fileURL = URL(fileURLWithPath: dbPath)
                let fileData: Data
                
                do {
                    fileData = try Data(contentsOf: fileURL, options: .mappedIfSafe)
                    print("DEBUG: ✅ Read \(fileData.count) bytes from database using Data(contentsOf:)")
                } catch let error1 {
                    print("DEBUG: Method 1 failed: \(error1)")
                    // Method 2: Try with FileHandle
                    if let fileHandle = FileHandle(forReadingAtPath: dbPath) {
                        fileData = fileHandle.readDataToEndOfFile()
                        fileHandle.closeFile()
                        print("DEBUG: ✅ Read \(fileData.count) bytes from database using FileHandle")
                    } else {
                        throw error1
                    }
                }
                
                // Write to temp location
                try fileData.write(to: URL(fileURLWithPath: tempDBPath), options: .atomic)
                print("DEBUG: ✅ Database written to: \(tempDBPath)")
            } catch {
                print("DEBUG: ❌ Failed to read/write database: \(error)")
                print("DEBUG: Error details: \((error as NSError).localizedDescription)")
                print("DEBUG: Error code: \((error as NSError).code)")
                if let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("DEBUG: Underlying error: \(underlyingError.localizedDescription)")
                    print("DEBUG: Underlying error code: \(underlyingError.code)")
                }
                print("DEBUG: Full Disk Access may not be working. Make sure:")
                print("DEBUG:   1. App is added to Full Disk Access in System Settings")
                print("DEBUG:   2. Toggle is ON (enabled)")
                print("DEBUG:   3. App was completely quit and restarted after adding")
                return nil
            }
            
            // Open the copied database (we have write access to temp directory)
            let db = FMDatabase(path: tempDBPath)
            db.shouldCacheStatements = false
            
            // Open the database
            if db.open() {
                // Verify we can actually query
                if let resultSet = db.executeQuery("SELECT name FROM sqlite_master WHERE type='table' LIMIT 1", withArgumentsIn: []) {
                    resultSet.close()
                    cloudTabsDatabase = db
                    print("DEBUG: ✅ Successfully opened CloudTabs.db database")
                    
                    // Clean up temp file when done (store path for cleanup)
                    // Note: We'll keep it open for the lifetime of the reader
                    return db
                } else {
                    print("DEBUG: ⚠️ Database opened but cannot query")
                    db.close()
                    try? fileManager.removeItem(atPath: tempDBPath)
                }
            } else {
                let errorCode = db.lastErrorCode()
                let errorMessage = db.lastErrorMessage()
                print("DEBUG: ❌ Failed to open copied database")
                print("DEBUG: SQLite error code: \(errorCode)")
                print("DEBUG: SQLite error message: \(errorMessage)")
                try? fileManager.removeItem(atPath: tempDBPath)
            }
            
            return nil
        }
        return cloudTabsDatabase
    }
    
    private var deviceIDs: [String]? {
        guard let db = database else { return nil }
        
        var deviceIDs: [String] = []
        if let resultSet = db.executeQuery("SELECT device_uuid from cloud_tab_devices GROUP BY device_uuid", withArgumentsIn: []) {
            while resultSet.next() {
                if let deviceID = resultSet.string(forColumn: "device_uuid") {
                    deviceIDs.append(deviceID)
                }
            }
            resultSet.close()
        }
        
        return deviceIDs.isEmpty ? nil : deviceIDs
    }
    
    private func deviceName(forID deviceID: String) -> String? {
        guard let db = database else { return nil }
        
        if let resultSet = db.executeQuery("SELECT device_name from cloud_tab_devices WHERE device_uuid = ?", withArgumentsIn: [deviceID]) {
            while resultSet.next() {
                let name = resultSet.string(forColumn: "device_name")
                resultSet.close()
                return name
            }
            resultSet.close()
        }
        
        return nil
    }
    
    private func tabs(forDeviceID deviceID: String) -> [[String: Any]]? {
        guard let db = database else { return nil }
        
        var tabs: [[String: Any]] = []
        let query = "SELECT url, title, position from cloud_tabs WHERE device_uuid = ?"
        
        if let resultSet = db.executeQuery(query, withArgumentsIn: [deviceID]) {
            while resultSet.next() {
                guard let url = resultSet.string(forColumn: "url"),
                      let title = resultSet.string(forColumn: "title") else {
                    continue
                }
                
                let position = resultSet.data(forColumn: "position")
                let sortValue = sortValue(forData: position) ?? 0
                
                tabs.append([
                    "URL": url,
                    "Title": title.isEmpty ? url : title,
                    "SortValue": sortValue
                ])
            }
            resultSet.close()
        }
        
        tabs.sort { ($0["SortValue"] as? Int ?? 0) < ($1["SortValue"] as? Int ?? 0) }
        
        return tabs.isEmpty ? nil : tabs
    }
    
    private var modificationDate: Date? {
        let preferencesURL = URL(fileURLWithPath: CloudTabsDBReader.safariLibraryDirectory().appendingPathComponent("CloudTabs.db"))
        
        var modificationDate: AnyObject?
        try? (preferencesURL as NSURL).getResourceValue(&modificationDate, forKey: .contentModificationDateKey)
        
        return modificationDate as? Date
    }
    
    private func sortValue(forData data: Data?) -> Int? {
        guard let data = data else { return nil }
        
        guard let inflated = data.zlibInflate() else { return nil }
        
        guard let jsonObject = try? JSONSerialization.jsonObject(with: inflated, options: []) as? [String: Any],
              let sortValues = jsonObject["sortValues"] as? [[String: Any]],
              let sortValueDictionary = sortValues.last,
              let sortValue = sortValueDictionary["sortValue"] as? Int else {
            return nil
        }
        
        return sortValue
    }
}

