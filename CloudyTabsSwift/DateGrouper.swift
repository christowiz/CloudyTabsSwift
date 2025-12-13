//
//  DateGrouper.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import Foundation

struct DateGroup {
    let dateCategory: DateCategory
    let tabs: [TabItem]
    
    var displayName: String {
        return dateCategory.displayName
    }
    
    var count: Int {
        return tabs.count
    }
}

enum DateCategory: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case older = "Older"
    
    var displayName: String {
        return self.rawValue
    }
    
    var sortOrder: Int {
        switch self {
        case .today: return 0
        case .yesterday: return 1
        case .thisWeek: return 2
        case .thisMonth: return 3
        case .older: return 4
        }
    }
}

class DateGrouper {
    
    static func groupTabsByDate(_ tabs: [TabItem]) -> [DateGroup] {
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [DateCategory: [TabItem]] = [:]
        
        for tab in tabs {
            guard let date = tab.lastViewedDate else {
                // Tabs without dates go to "Older"
                groups[.older, default: []].append(tab)
                continue
            }
            
            if calendar.isDateInToday(date) {
                groups[.today, default: []].append(tab)
            } else if calendar.isDateInYesterday(date) {
                groups[.yesterday, default: []].append(tab)
            } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
                groups[.thisWeek, default: []].append(tab)
            } else if calendar.isDate(date, equalTo: now, toGranularity: .month) {
                groups[.thisMonth, default: []].append(tab)
            } else {
                groups[.older, default: []].append(tab)
            }
        }
        
        // Sort tabs within each group by most recent first
        for category in groups.keys {
            groups[category]?.sort { tab1, tab2 in
                let time1 = tab1.lastViewedTime
                let time2 = tab2.lastViewedTime
                if time1 > 0 && time2 > 0 {
                    return time1 > time2
                }
                return tab1.sortValue < tab2.sortValue
            }
        }
        
        // Convert to DateGroup array and sort by category order
        return DateCategory.allCases.compactMap { category in
            guard let tabs = groups[category], !tabs.isEmpty else { return nil }
            return DateGroup(dateCategory: category, tabs: tabs)
        }
    }
    
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE" // Day of week
            return formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMMM d" // Month day
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMMM d, yyyy" // Full date
            return formatter.string(from: date)
        }
    }
}
