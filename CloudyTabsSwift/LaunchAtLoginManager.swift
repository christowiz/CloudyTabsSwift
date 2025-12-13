//
//  LaunchAtLoginManager.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import Foundation
import ServiceManagement

class LaunchAtLoginManager {
    
    static func willStartAtLogin(_ helperBundleId: String) -> Bool {
        // Despite being deprecated, still the preferred API
        // https://github.com/alexzielenski/StartAtLoginController/issues/12#issuecomment-307525807
        var jobDictionariesRef: Unmanaged<CFArray>?
        
        #if swift(>=5.0)
        jobDictionariesRef = SMCopyAllJobDictionaries(kSMDomainUserLaunchd)
        #else
        // For older Swift versions, use the deprecated API directly
        jobDictionariesRef = SMCopyAllJobDictionaries(kSMDomainUserLaunchd)
        #endif
        
        guard let jobDictionariesRef = jobDictionariesRef,
              let jobDictionaries = jobDictionariesRef.takeRetainedValue() as? [[String: Any]] else {
            return false
        }
        
        let filteredArray = jobDictionaries.filter { ($0["Label"] as? String) == helperBundleId }
        
        guard let launchItem = filteredArray.first,
              let onDemand = launchItem["OnDemand"] as? Bool else {
            return false
        }
        
        return onDemand
    }
    
    static func setStartAtLogin(_ helperBundleId: String, enabled: Bool) {
        SMLoginItemSetEnabled(helperBundleId as CFString, enabled)
    }
}
