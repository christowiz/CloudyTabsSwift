//
//  LoadingMenuItem.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import AppKit

class LoadingMenuItem: NSMenuItem {
    
    override init(title string: String, action selector: Selector?, keyEquivalent charCode: String) {
        super.init(title: string, action: selector, keyEquivalent: charCode)
        
        let progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        progressIndicator.isBezeled = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.controlSize = .small
        progressIndicator.style = .spinning
        progressIndicator.sizeToFit()
        
        view = progressIndicator
        progressIndicator.startAnimation(self)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
