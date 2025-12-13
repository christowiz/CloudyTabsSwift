//
//  UserDefaultsController.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import Foundation

class UserDefaultsController {
    
    private static let listAllDevicesKey = "ListAllDevices"
    private static let sortByMostRecentKey = "SortByMostRecent"
    private static let showWindowModeKey = "ShowWindowMode"
    private static let dateSectionsEnabledKey = "DateSectionsEnabled"
    
    static func registerUserDefaults() {
        let defaultValues: [String: Any] = [
            listAllDevicesKey: false,
            sortByMostRecentKey: true,  // Default to sorting by most recent
            showWindowModeKey: false,   // Default to menubar-only
            dateSectionsEnabledKey: false  // Default to no date sections
        ]
        UserDefaults.standard.register(defaults: defaultValues)
    }
    
    static func shouldListAllDevices() -> Bool {
        return UserDefaults.standard.bool(forKey: listAllDevicesKey)
    }
    
    static func shouldSortByMostRecent() -> Bool {
        return UserDefaults.standard.bool(forKey: sortByMostRecentKey)
    }
    
    static func setSortByMostRecent(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: sortByMostRecentKey)
    }
    
    static func shouldShowWindowMode() -> Bool {
        return UserDefaults.standard.bool(forKey: showWindowModeKey)
    }
    
    static func setShowWindowMode(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: showWindowModeKey)
    }
    
    static func shouldUseDateSections() -> Bool {
        return UserDefaults.standard.bool(forKey: dateSectionsEnabledKey)
    }
    
    static func setUseDateSections(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: dateSectionsEnabledKey)
    }
}
