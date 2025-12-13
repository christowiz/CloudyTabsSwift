//
//  UserDefaultsController.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import Foundation

class UserDefaultsController {
    
    private static let listAllDevicesKey = "ListAllDevices"
    
    static func registerUserDefaults() {
        let defaultValues: [String: Any] = [listAllDevicesKey: false]
        UserDefaults.standard.register(defaults: defaultValues)
    }
    
    static func shouldListAllDevices() -> Bool {
        return UserDefaults.standard.bool(forKey: listAllDevicesKey)
    }
}
