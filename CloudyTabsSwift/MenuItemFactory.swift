//
//  MenuItemFactory.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import AppKit

class MenuItemFactory {
    
    private static let iconSize = NSSize(width: 19, height: 19)
    private static let maxTitleLength = 60
    
    static func menuItem(withTitle tabTitle: String, urlPath: String, action: Selector) -> NSMenuItem {
        let displayTitle = tabTitle.count > maxTitleLength
            ? String(tabTitle.prefix(maxTitleLength - 1)) + "…"
            : tabTitle
        
        let tabMenuItem = NSMenuItem(title: displayTitle, action: action, keyEquivalent: "")
        
        guard let url = URL.decodeURL(urlPath) else {
            return tabMenuItem
        }
        
        tabMenuItem.representedObject = url
        tabMenuItem.toolTip = url.relativeString
        
        // For now, use a placeholder image. In the original, DSFavIconManager was used
        // to fetch favicons. You would need to integrate a similar library or implement
        // favicon fetching functionality.
        if url.host != nil {
            // Placeholder for favicon - would need DSFavIconManager or similar
            tabMenuItem.image = NSImage(named: "Globe")
        } else {
            tabMenuItem.image = NSImage(named: "Globe")
        }
        
        tabMenuItem.image?.size = iconSize
        
        return tabMenuItem
    }
}
