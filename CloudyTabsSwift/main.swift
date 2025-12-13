//
//  main.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
// NSApplication delegate is always called on main thread, so this is safe
app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
