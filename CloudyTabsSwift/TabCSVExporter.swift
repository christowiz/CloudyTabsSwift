//
//  TabCSVExporter.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

class TabCSVExporter {
    
    static func exportTabs(_ tabData: [[String: Any]], deviceName: String) {
        let temporaryFilePath = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString)
        
        var csvContent = "URL,Title\n"
        
        for tab in tabData {
            let url = tab["URL"] as? String ?? ""
            let title = tab["Title"] as? String ?? ""
            
            // Escape quotes and wrap in quotes if contains comma
            let escapedURL = url.contains(",") ? "\"\(url.replacingOccurrences(of: "\"", with: "\"\""))\"" : url
            let escapedTitle = title.contains(",") ? "\"\(title.replacingOccurrences(of: "\"", with: "\"\""))\"" : title
            
            csvContent += "\(escapedURL),\(escapedTitle)\n"
        }
        
        do {
            try csvContent.write(toFile: temporaryFilePath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write CSV file: \(error)")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(deviceName).csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                let temporaryFileURL = URL(fileURLWithPath: temporaryFilePath)
                
                do {
                    try FileManager.default.copyItem(at: temporaryFileURL, to: url)
                } catch {
                    print("Failed to copy file: \(error)")
                }
            }
        }
        
        savePanel.orderFrontRegardless()
    }
}

