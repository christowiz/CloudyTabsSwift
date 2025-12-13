//
//  AppDelegate.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    var statusItem: NSStatusItem?
    var menu: NSMenu?
    
    private var lastUpdateDate: Date?
    private var cloudTabsDBReader: CloudTabsDBReader?
    private var readingListReader: ReadingListReader?
    private var tabData: [[String: Any]]?
    private var readingListItems: [[String: Any]]?
    
    private let helperBundleID = "com.joshparnham.CloudyTabsHelper"
    
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Print app path for Full Disk Access verification
        print("DEBUG: App bundle path: \(Bundle.main.bundlePath)")
        print("DEBUG: Make sure THIS path is added to Full Disk Access in System Settings")
        
        cloudTabsDBReader = CloudTabsDBReader()
        readingListReader = ReadingListReader()
        
        UserDefaultsController.registerUserDefaults()
        
        // Initialize menu before creating status item
        if menu == nil {
            menu = NSMenu()
            menu?.delegate = self
        }
        
        createStatusItem()
        updateMenu()
        setupQueue()
        updateUserInterface()
    }
    
    // MARK: - Menu Actions
    
    @objc func tabMenuItemClicked(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        
        let modifierFlags = NSEvent.modifierFlags
        
        if modifierFlags.contains(.command) {
            NSWorkspace.shared.open([url], withAppBundleIdentifier: nil, options: .withoutActivation, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
        } else if modifierFlags.contains(.option) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([url as NSPasteboardWriting])
        } else {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func openAllFromClicked(_ sender: NSMenuItem) {
        guard let deviceID = sender.representedObject as? String else { return }
        
        let launchOptions: NSWorkspace.LaunchOptions = NSEvent.modifierFlags.contains(.command) ? .withoutActivation : []
        
        DispatchQueue.global(qos: .default).async {
            guard let tabData = self.tabData,
                  let deviceTabs = tabData.first(where: { ($0["DeviceName"] as? String) == deviceID }),
                  let tabs = deviceTabs["Tabs"] as? [[String: Any]] else {
                return
            }
            
            for tabDictionary in tabs {
                guard let urlString = tabDictionary["URL"] as? String,
                      let url = URL.decodeURL(urlString) else {
                    continue
                }
                
                NSWorkspace.shared.open([url], withAppBundleIdentifier: nil, options: launchOptions, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
                usleep(500000) // 0.5 second delay
            }
        }
    }
    
    @objc func exportAllFromClicked(_ sender: NSMenuItem) {
        guard let deviceID = sender.representedObject as? String,
              let tabData = self.tabData,
              let deviceTabs = tabData.first(where: { ($0["DeviceName"] as? String) == deviceID }),
              let tabs = deviceTabs["Tabs"] as? [[String: Any]],
              let deviceName = deviceTabs["DeviceName"] as? String else {
            return
        }
        
        TabCSVExporter.exportTabs(tabs, deviceName: deviceName)
    }
    
    @objc func openAtLoginToggled(_ sender: NSMenuItem) {
        setStartAtLogin(!startAtLogin)
    }
    
    @objc func promptFullDiskAccess(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Enable Full Disk Access", comment: "")
        alert.informativeText = NSLocalizedString("CloudyTabs requies Full Disk Access to access your Safari data. Click \"Enable\" to open System Prefences and then click the checkbox next to \"CloudyTabs\".", comment: "")
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: NSLocalizedString("Enable", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        
        let alertResult = alert.runModal()
        if alertResult == .alertFirstButtonReturn {
            if let url = URL.privacyAllFilesSystemPreferencesURL() {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc func checkForUpdates(_ sender: NSMenuItem) {
        // Sparkle integration would go here
        // SUUpdater.shared().checkForUpdates(sender)
    }
    
    @objc func quit(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
    
    // MARK: - Methods
    
    private func appBundleName() -> String {
        return Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "CloudyTabs"
    }
    
    private func appBundleVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private func setupQueue() {
        // File watching would be set up here
        // For now, we'll rely on menuWillOpen to refresh
    }
    
    private func updateUserInterface() {
        cloudTabsDBReader?.fetchTabData { [weak self] tabData in
            self?.tabData = tabData
            
            DispatchQueue.main.async {
                self?.updateMenu()
            }
        }
        
        readingListReader?.fetchReadingListItems { [weak self] readingListItems in
            self?.readingListItems = readingListItems
            
            DispatchQueue.main.async {
                self?.updateMenu()
            }
        }
    }
    
    private func requiresFullDiskAccess() -> Bool {
        return !(cloudTabsDBReader?.permissionsToReadFile() ?? false)
    }
    
    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Try to load StatusIcon, fallback to system image if not found
        if let statusIcon = NSImage(named: "StatusIcon") {
            statusItem?.button?.image = statusIcon
        } else {
            // Fallback to system image if StatusIcon asset is missing
            let systemImage = NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: "CloudyTabs")
            systemImage?.isTemplate = true
            statusItem?.button?.image = systemImage
            print("Warning: StatusIcon image not found, using fallback system image")
        }
        
        statusItem?.menu = menu
        statusItem?.button?.isEnabled = true
        
        let toolTip = String(format: NSLocalizedString("%@ (%@)", comment: ""), appBundleName(), appBundleVersion())
        statusItem?.button?.toolTip = toolTip
    }
    
    private func updateMenu() {
        menu?.removeAllItems()
        
        guard let menu = menu else { return }
        
        if let tabData = tabData {
            let openAllTabsSubMenu = NSMenu(title: "Open All Tabs From")
            openAllTabsSubMenu.autoenablesItems = false
            
            let exportTabsSubMenu = NSMenu(title: "Export All Tabs From")
            exportTabsSubMenu.autoenablesItems = false
            
            for deviceTabs in tabData {
                guard let tabs = deviceTabs["Tabs"] as? [[String: Any]],
                      tabs.count > 0 else {
                    continue
                }
                
                let deviceName = deviceTabs["DeviceName"] as? String ?? ""
                let tabCount = tabs.count
                let localizedTabCount = NumberFormatter.localizedString(from: NSNumber(value: tabCount), number: .none)
                let deviceMenuItemTitle = "\(deviceName) (\(localizedTabCount))"
                
                // Add device to "Export All Tabs From" submenu
                let exportAllTabsFromDeviceMenuItem = NSMenuItem(title: deviceMenuItemTitle, action: #selector(exportAllFromClicked(_:)), keyEquivalent: "")
                exportAllTabsFromDeviceMenuItem.representedObject = deviceName
                exportAllTabsFromDeviceMenuItem.isEnabled = tabs.count >= 1
                exportTabsSubMenu.addItem(exportAllTabsFromDeviceMenuItem)
                
                // Hide tabs from Mac where CloudyTabs is currently running on, unless the user has explicitly set the user default
                if !UserDefaultsController.shouldListAllDevices(),
                   Host.current().localizedName == deviceName {
                    continue
                }
                
                // Add a separator if this device isn't the first in the list
                if menu.items.count > 0 {
                    menu.addItem(NSMenuItem.separator())
                }
                
                let deviceMenuItem = NSMenuItem(title: deviceName, action: nil, keyEquivalent: "")
                deviceMenuItem.isEnabled = false
                menu.addItem(deviceMenuItem)
                
                // Add device to "Open All Tabs From" submenu
                let openAllTabsFromDeviceMenuItem = NSMenuItem(title: deviceMenuItemTitle, action: #selector(openAllFromClicked(_:)), keyEquivalent: "")
                openAllTabsFromDeviceMenuItem.representedObject = deviceName
                openAllTabsFromDeviceMenuItem.isEnabled = tabs.count >= 1
                openAllTabsSubMenu.addItem(openAllTabsFromDeviceMenuItem)
                
                for tabDictionary in tabs {
                    if let title = tabDictionary["Title"] as? String,
                       let urlPath = tabDictionary["URL"] as? String {
                        let menuItem = MenuItemFactory.menuItem(withTitle: title, urlPath: urlPath, action: #selector(tabMenuItemClicked(_:)))
                        menu.addItem(menuItem)
                    }
                }
            }
            
            if let readingListItems = readingListItems, readingListItems.count > 0 {
                if menu.items.count > 0 {
                    menu.addItem(NSMenuItem.separator())
                }
                
                let readingListTitle = NSMenuItem(title: NSLocalizedString("Reading List", comment: ""), action: nil, keyEquivalent: "")
                readingListTitle.isEnabled = false
                menu.addItem(readingListTitle)
                
                for bookmarkDictionary in readingListItems {
                    if let uriDictionary = bookmarkDictionary["URIDictionary"] as? [String: Any],
                       let title = uriDictionary["title"] as? String,
                       let urlString = bookmarkDictionary["URLString"] as? String {
                        let menuItem = MenuItemFactory.menuItem(withTitle: title, urlPath: urlString, action: #selector(tabMenuItemClicked(_:)))
                        menu.addItem(menuItem)
                    }
                }
            }
            
            if menu.items.count > 0 {
                menu.addItem(NSMenuItem.separator())
            }
            
            if tabData.count >= 1 {
                let openAllTabsMenu = NSMenuItem(title: NSLocalizedString("Open All Tabs From", comment: ""), action: nil, keyEquivalent: "")
                menu.addItem(openAllTabsMenu)
                openAllTabsMenu.submenu = openAllTabsSubMenu
                openAllTabsMenu.isEnabled = openAllTabsSubMenu.items.count >= 1
                
                let exportAllTabsMenu = NSMenuItem(title: NSLocalizedString("Export All Tabs From", comment: ""), action: nil, keyEquivalent: "")
                menu.addItem(exportAllTabsMenu)
                exportAllTabsMenu.submenu = exportTabsSubMenu
                exportAllTabsMenu.isEnabled = exportTabsSubMenu.items.count >= 1
            }
        } else {
            if requiresFullDiskAccess() {
                let fullDiskAccessItem = NSMenuItem(title: NSLocalizedString("Requires Full Disk Access…", comment: ""), action: #selector(promptFullDiskAccess(_:)), keyEquivalent: "")
                menu.addItem(fullDiskAccessItem)
                menu.addItem(NSMenuItem.separator())
            } else {
                let loadingMenuItem = LoadingMenuItem(title: "Loading", action: nil, keyEquivalent: "")
                menu.addItem(loadingMenuItem)
            }
        }
        
        let checkForUpdatesItem = NSMenuItem(title: NSLocalizedString("Check For Updates…", comment: ""), action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        menu.addItem(checkForUpdatesItem)
        
        let openAtLoginItem = NSMenuItem(title: String(format: NSLocalizedString("Launch %@ At Login", comment: ""), appBundleName()), action: #selector(openAtLoginToggled(_:)), keyEquivalent: "")
        openAtLoginItem.state = startAtLogin ? .on : .off
        menu.addItem(openAtLoginItem)
        
        let quitMenuItem = NSMenuItem(title: String(format: NSLocalizedString("Quit %@", comment: ""), appBundleName()), action: #selector(quit(_:)), keyEquivalent: "q")
        menu.addItem(quitMenuItem)
        
        lastUpdateDate = Date()
    }
    
    // MARK: - Launch at Login
    
    private var startAtLogin: Bool {
        return LaunchAtLoginManager.willStartAtLogin(helperBundleID)
    }
    
    private func setStartAtLogin(_ enabled: Bool) {
        LaunchAtLoginManager.setStartAtLogin(helperBundleID, enabled: enabled)
        updateMenu()
    }
    
    // MARK: - Menu Delegate
    
    @MainActor
    func menuWillOpen(_ menu: NSMenu) {
        updateUserInterface()
    }
    
    // MARK: - Getters
    
    override init() {
        super.init()
    }
}
