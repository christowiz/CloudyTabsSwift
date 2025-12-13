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
    var mainWindowController: MainWindowController?
    
    private var lastUpdateDate: Date?
    private var cloudTabsDBReader: CloudTabsDBReader?
    private var readingListReader: ReadingListReader?
    private var tabData: [[String: Any]]?
    private var readingListItems: [[String: Any]]?
    private var allTabItems: [TabItem]?
    
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

        // Set activation policy based on window mode
        updateActivationPolicy()

        // Hide menu bar in menubar-only mode
        if !UserDefaultsController.shouldShowWindowMode() {
            NSApplication.shared.mainMenu = nil
        }

        // Create window controller if window mode is enabled
        if UserDefaultsController.shouldShowWindowMode() {
            mainWindowController = MainWindowController()
            mainWindowController?.showWindow(nil)
            // Data will be updated when fetchTabItems completes
        }
        
        // Listen for reload notifications from window menu
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReloadTabsNotification(_:)),
            name: NSNotification.Name("ReloadTabs"),
            object: nil
        )
        
        // Listen for window close/show notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidClose(_:)),
            name: NSNotification.Name("WindowDidClose"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidShow(_:)),
            name: NSNotification.Name("WindowDidShow"),
            object: nil
        )
        
        createStatusItem()
        updateMenu()
        setupQueue()
        updateUserInterface()
    }
    
    @objc func handleReloadTabsNotification(_ notification: Notification) {
        updateUserInterface()
    }
    
    @objc func handleWindowDidClose(_ notification: Notification) {
        updateActivationPolicy()
        // Update menu to reflect window is closed
        updateMenu()
    }
    
    @objc func handleWindowDidShow(_ notification: Notification) {
        // Update preference to reflect window is shown
        UserDefaultsController.setShowWindowMode(true)
        // Update menu to reflect window is open
        updateMenu()
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
    
    @objc func sortByMostRecentToggled(_ sender: NSMenuItem) {
        let currentValue = UserDefaultsController.shouldSortByMostRecent()
        UserDefaultsController.setSortByMostRecent(!currentValue)
        // Refresh the menu to show updated sort order
        updateUserInterface()
    }
    
    @objc func toggleWindowMode(_ sender: NSMenuItem) {
        let windowIsVisible = mainWindowController?.window?.isVisible ?? false
        
        if !windowIsVisible {
            // Show window
            if mainWindowController == nil {
                mainWindowController = MainWindowController()
            }
            mainWindowController?.showWindow(nil)
            // Update tabs in window - use existing data or trigger refresh
            if let tabItems = allTabItems {
                mainWindowController?.updateTabs(tabItems)
            } else {
                // If no data yet, trigger a refresh
                updateUserInterface()
            }
            // Menu bar will be shown by MainWindowController
            UserDefaultsController.setShowWindowMode(true)
        } else {
            // Hide window (but don't destroy it)
            mainWindowController?.window?.close()
            // Hide menu bar in menubar-only mode
            NSApplication.shared.mainMenu = nil
            UserDefaultsController.setShowWindowMode(false)
        }
        
        // Update activation policy (Dock icon visibility)
        updateActivationPolicy()
        
        updateMenu()
    }
    
    private func updateActivationPolicy() {
        // If window is visible, show in Dock (regular app)
        // If window is hidden/closed, hide from Dock (menubar-only)
        let windowVisible = mainWindowController?.window?.isVisible ?? false
        
        if windowVisible {
            // Show in Dock when window is open
            NSApplication.shared.setActivationPolicy(.regular)
        } else {
            // Hide from Dock when window is closed (menubar-only)
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
    
    @objc func toggleDateSections(_ sender: NSMenuItem) {
        let currentValue = UserDefaultsController.shouldUseDateSections()
        UserDefaultsController.setUseDateSections(!currentValue)
        // Refresh the menu to show updated grouping
        updateMenu()
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
        // Fetch tab data for menubar first
        cloudTabsDBReader?.fetchTabData { [weak self] tabData in
            self?.tabData = tabData
            
            DispatchQueue.main.async {
                self?.updateMenu()
            }
            
            // Convert tabData to TabItems for window mode
            // This reuses the data we already fetched instead of making another DB call
            var tabItems: [TabItem] = []
            
            if let tabData = tabData {
                for deviceTabs in tabData {
                    guard let tabs = deviceTabs["Tabs"] as? [[String: Any]],
                          let deviceName = deviceTabs["DeviceName"] as? String,
                          let deviceID = deviceTabs["DeviceID"] as? String else {
                        continue
                    }
                    
                    for tabDict in tabs {
                        let tabItem = TabItem(from: tabDict, deviceName: deviceName, deviceID: deviceID)
                        tabItems.append(tabItem)
                    }
                }
            }
            
            print("DEBUG: AppDelegate - converted \(tabItems.count) tab items from tabData")
            self?.allTabItems = tabItems.isEmpty ? nil : tabItems

            DispatchQueue.main.async {
                print("DEBUG: AppDelegate - updating window controller on main thread")
                self?.mainWindowController?.updateTabs(tabItems.isEmpty ? nil : tabItems)
                print("DEBUG: AppDelegate - window controller updated")
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
            // ===== ACTIONS SECTION (AT TOP) =====
            let openAllTabsSubMenu = NSMenu(title: "Open All Tabs From")
            openAllTabsSubMenu.autoenablesItems = false
            
            let exportTabsSubMenu = NSMenu(title: "Export All Tabs From")
            exportTabsSubMenu.autoenablesItems = false
            
            // Build submenus first
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
                
                // Add device to "Open All Tabs From" submenu
                let openAllTabsFromDeviceMenuItem = NSMenuItem(title: deviceMenuItemTitle, action: #selector(openAllFromClicked(_:)), keyEquivalent: "")
                openAllTabsFromDeviceMenuItem.representedObject = deviceName
                openAllTabsFromDeviceMenuItem.isEnabled = tabs.count >= 1
                openAllTabsSubMenu.addItem(openAllTabsFromDeviceMenuItem)
            }
            
            // ===== STATIC SETTINGS ITEMS (AT TOP) =====
            // Window mode toggle - check actual window visibility, not just preference
            let windowIsVisible = mainWindowController?.window?.isVisible ?? false
            let showWindowItem = NSMenuItem(title: windowIsVisible ? NSLocalizedString("Hide Window", comment: "") : NSLocalizedString("Show Window", comment: ""), action: #selector(toggleWindowMode(_:)), keyEquivalent: "w")
            menu.addItem(showWindowItem)
            
            // Date sections toggle
            let dateSectionsItem = NSMenuItem(title: NSLocalizedString("Group By Date", comment: ""), action: #selector(toggleDateSections(_:)), keyEquivalent: "")
            dateSectionsItem.state = UserDefaultsController.shouldUseDateSections() ? .on : .off
            menu.addItem(dateSectionsItem)
            
            // Check for updates
            let checkForUpdatesItem = NSMenuItem(title: NSLocalizedString("Check For Updates…", comment: ""), action: #selector(checkForUpdates(_:)), keyEquivalent: "")
            menu.addItem(checkForUpdatesItem)
            
            // Launch at login
            let openAtLoginItem = NSMenuItem(title: String(format: NSLocalizedString("Launch %@ At Login", comment: ""), appBundleName()), action: #selector(openAtLoginToggled(_:)), keyEquivalent: "")
            openAtLoginItem.state = startAtLogin ? .on : .off
            menu.addItem(openAtLoginItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // ===== ACTION ITEMS =====
            if tabData.count >= 1 {
                let openAllTabsMenu = NSMenuItem(title: NSLocalizedString("Open All Tabs From", comment: ""), action: nil, keyEquivalent: "")
                menu.addItem(openAllTabsMenu)
                openAllTabsMenu.submenu = openAllTabsSubMenu
                openAllTabsMenu.isEnabled = openAllTabsSubMenu.items.count >= 1
                
                let exportAllTabsMenu = NSMenuItem(title: NSLocalizedString("Export All Tabs From", comment: ""), action: nil, keyEquivalent: "")
                menu.addItem(exportAllTabsMenu)
                exportAllTabsMenu.submenu = exportTabsSubMenu
                exportAllTabsMenu.isEnabled = exportTabsSubMenu.items.count >= 1
                
                let sortByMostRecentItem = NSMenuItem(title: NSLocalizedString("Sort By Most Recent", comment: ""), action: #selector(sortByMostRecentToggled(_:)), keyEquivalent: "")
                sortByMostRecentItem.state = UserDefaultsController.shouldSortByMostRecent() ? .on : .off
                menu.addItem(sortByMostRecentItem)
                
                menu.addItem(NSMenuItem.separator())
            }
            
            // ===== TABS SECTION =====
            // Convert tabData to TabItems for date grouping if needed
            var allTabsForGrouping: [TabItem] = []
            
            // First, collect all tabs for date grouping
            for deviceTabs in tabData {
                guard let tabs = deviceTabs["Tabs"] as? [[String: Any]],
                      let deviceName = deviceTabs["DeviceName"] as? String,
                      tabs.count > 0 else {
                    continue
                }
                
                // Get deviceID - it might not be in the dictionary, so we'll find it
                var deviceID = deviceTabs["DeviceID"] as? String
                if deviceID == nil {
                    // Find deviceID by matching device name
                    if let deviceIDs = cloudTabsDBReader?.deviceIDs {
                        for id in deviceIDs {
                            if cloudTabsDBReader?.deviceName(forID: id) == deviceName {
                                deviceID = id
                                break
                            }
                        }
                    }
                }
                deviceID = deviceID ?? deviceName // Fallback to device name
                
                // Hide tabs from Mac where CloudyTabs is currently running on, unless the user has explicitly set the user default
                if !UserDefaultsController.shouldListAllDevices(),
                   Host.current().localizedName == deviceName {
                    continue
                }
                
                // Convert to TabItems for date grouping
                for tabDictionary in tabs {
                    if let title = tabDictionary["Title"] as? String,
                       let urlPath = tabDictionary["URL"] as? String {
                        let tabItem = TabItem(from: tabDictionary, deviceName: deviceName, deviceID: deviceID ?? deviceName)
                        allTabsForGrouping.append(tabItem)
                    }
                }
            }
            
            // Add tabs to menu - either with date sections or flat list
            if UserDefaultsController.shouldUseDateSections() && !allTabsForGrouping.isEmpty {
                // Group by date
                let dateGroups = DateGrouper.groupTabsByDate(allTabsForGrouping)
                
                for dateGroup in dateGroups {
                    let dateMenu = NSMenu()
                    dateMenu.autoenablesItems = false
                    
                    for tab in dateGroup.tabs {
                        let menuItem = MenuItemFactory.menuItem(withTitle: tab.title, urlPath: tab.url, action: #selector(tabMenuItemClicked(_:)))
                        dateMenu.addItem(menuItem)
                    }
                    
                    let dateMenuItem = NSMenuItem(title: "\(dateGroup.displayName) (\(dateGroup.count))", action: nil, keyEquivalent: "")
                    dateMenuItem.submenu = dateMenu
                    menu.addItem(dateMenuItem)
                }
            } else {
                // Flat list by device (original behavior)
                for deviceTabs in tabData {
                    guard let tabs = deviceTabs["Tabs"] as? [[String: Any]],
                          let deviceName = deviceTabs["DeviceName"] as? String,
                          tabs.count > 0 else {
                        continue
                    }
                    
                    // Hide tabs from Mac where CloudyTabs is currently running on
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
                    
                    for tabDictionary in tabs {
                        if let title = tabDictionary["Title"] as? String,
                           let urlPath = tabDictionary["URL"] as? String {
                            let menuItem = MenuItemFactory.menuItem(withTitle: title, urlPath: urlPath, action: #selector(tabMenuItemClicked(_:)))
                            menu.addItem(menuItem)
                        }
                    }
                }
            }
            
            // ===== READING LIST SECTION =====
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
        } else {
            // ===== STATIC SETTINGS ITEMS (AT TOP, EVEN WHEN NO DATA) =====
            // Window mode toggle - check actual window visibility, not just preference
            let windowIsVisible = mainWindowController?.window?.isVisible ?? false
            let showWindowItem = NSMenuItem(title: windowIsVisible ? NSLocalizedString("Hide Window", comment: "") : NSLocalizedString("Show Window", comment: ""), action: #selector(toggleWindowMode(_:)), keyEquivalent: "w")
            menu.addItem(showWindowItem)
            
            // Date sections toggle
            let dateSectionsItem = NSMenuItem(title: NSLocalizedString("Group By Date", comment: ""), action: #selector(toggleDateSections(_:)), keyEquivalent: "")
            dateSectionsItem.state = UserDefaultsController.shouldUseDateSections() ? .on : .off
            menu.addItem(dateSectionsItem)
            
            // Check for updates
            let checkForUpdatesItem = NSMenuItem(title: NSLocalizedString("Check For Updates…", comment: ""), action: #selector(checkForUpdates(_:)), keyEquivalent: "")
            menu.addItem(checkForUpdatesItem)
            
            // Launch at login
            let openAtLoginItem = NSMenuItem(title: String(format: NSLocalizedString("Launch %@ At Login", comment: ""), appBundleName()), action: #selector(openAtLoginToggled(_:)), keyEquivalent: "")
            openAtLoginItem.state = startAtLogin ? .on : .off
            menu.addItem(openAtLoginItem)
            
            menu.addItem(NSMenuItem.separator())
            
            if requiresFullDiskAccess() {
                let fullDiskAccessItem = NSMenuItem(title: NSLocalizedString("Requires Full Disk Access…", comment: ""), action: #selector(promptFullDiskAccess(_:)), keyEquivalent: "")
                menu.addItem(fullDiskAccessItem)
                menu.addItem(NSMenuItem.separator())
            } else {
                let loadingMenuItem = LoadingMenuItem(title: "Loading", action: nil, keyEquivalent: "")
                menu.addItem(loadingMenuItem)
                menu.addItem(NSMenuItem.separator())
            }
        }
        
        // ===== QUIT (AT BOTTOM) =====
        menu.addItem(NSMenuItem.separator())
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
