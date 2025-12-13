//
//  WindowDelegate.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import AppKit

class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    
    func windowWillClose(_ notification: Notification) {
        // Hide menu bar when window closes (menubar mode)
        if !UserDefaultsController.shouldShowWindowMode() {
            NSApplication.shared.mainMenu = nil
        }
        
        // Hide from Dock when window closes
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Update preference to reflect window is closed
        UserDefaultsController.setShowWindowMode(false)
        
        // Notify AppDelegate to update activation policy and menu
        NotificationCenter.default.post(name: NSNotification.Name("WindowDidClose"), object: nil)
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Show in Dock when window becomes key
        NSApplication.shared.setActivationPolicy(.regular)
    }
}
