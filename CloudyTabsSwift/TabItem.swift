//
//  TabItem.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import Foundation

struct TabItem {
    let url: String
    let title: String
    let deviceName: String
    let deviceID: String
    let lastViewedTime: TimeInterval
    let sortValue: Int
    
    var lastViewedDate: Date? {
        guard lastViewedTime > 0 else { return nil }
        return Date(timeIntervalSince1970: lastViewedTime)
    }
    
    init(url: String, title: String, deviceName: String, deviceID: String, lastViewedTime: TimeInterval = 0, sortValue: Int = 0) {
        self.url = url
        self.title = title.isEmpty ? url : title
        self.deviceName = deviceName
        self.deviceID = deviceID
        self.lastViewedTime = lastViewedTime
        self.sortValue = sortValue
    }
    
    init(from dictionary: [String: Any], deviceName: String, deviceID: String) {
        self.url = dictionary["URL"] as? String ?? ""
        self.title = dictionary["Title"] as? String ?? ""
        self.deviceName = deviceName
        self.deviceID = deviceID
        self.lastViewedTime = dictionary["LastViewedTime"] as? TimeInterval ?? 0
        self.sortValue = dictionary["SortValue"] as? Int ?? 0
    }
}
