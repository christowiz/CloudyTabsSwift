//
//  MainWindowController.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import AppKit

class MainWindowController: NSWindowController {
    
    private var tabsViewController: TabsViewController?
    
    convenience init() {
        // Create the tabs view controller first
        let viewController = TabsViewController()
        
        // Create window programmatically
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CloudyTabs"
        window.center()
        window.setFrameAutosaveName("CloudyTabsMainWindow")
        window.contentViewController = viewController
        window.delegate = WindowDelegate.shared
        
        // Create menu bar for the window
        let mainMenu = NSMenu()
        
        // App menu (CloudyTabs)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(withTitle: "About CloudyTabs", action: nil, keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Preferences…", action: nil, keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide CloudyTabs", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit CloudyTabs", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        mainMenu.addItem(appMenuItem)
        
        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        mainMenu.addItem(fileMenuItem)
        
        // Edit menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(editMenuItem)
        
        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "Reload", action: #selector(reloadTabs(_:)), keyEquivalent: "r")
        mainMenu.addItem(viewMenuItem)
        
        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        mainMenu.addItem(windowMenuItem)
        
        // Set the menu only when window is shown
        // This will be called when window is displayed
        NSApplication.shared.mainMenu = mainMenu
        
        self.init(window: window)
        self.tabsViewController = viewController
    }
    
    @objc func reloadTabs(_ sender: Any?) {
        // Trigger a refresh of tabs
        NotificationCenter.default.post(name: NSNotification.Name("ReloadTabs"), object: nil)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    func updateTabs(_ tabs: [TabItem]?) {
        print("DEBUG: MainWindowController.updateTabs called with \(tabs?.count ?? 0) tabs")
        tabsViewController?.updateTabs(tabs)
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        // Bring window to front and activate app
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        // Show menu bar when window is shown
        setupMenuBar()
        // Show in Dock when window opens
        NSApplication.shared.setActivationPolicy(.regular)
        
        // Notify AppDelegate that window was shown
        NotificationCenter.default.post(name: NSNotification.Name("WindowDidShow"), object: nil)
    }
    
    private func setupMenuBar() {
        // Create menu bar for the window
        let mainMenu = NSMenu()
        
        // App menu (CloudyTabs)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(withTitle: "About CloudyTabs", action: nil, keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Preferences…", action: nil, keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide CloudyTabs", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit CloudyTabs", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        mainMenu.addItem(appMenuItem)
        
        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        mainMenu.addItem(fileMenuItem)
        
        // Edit menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(editMenuItem)
        
        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "Reload", action: #selector(reloadTabs(_:)), keyEquivalent: "r")
        mainMenu.addItem(viewMenuItem)
        
        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        mainMenu.addItem(windowMenuItem)
        
        // Set the menu
        NSApplication.shared.mainMenu = mainMenu
    }
}
