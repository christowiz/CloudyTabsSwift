//
//  TabsViewController.swift
//  CloudyTabsSwift
//
//  Created by Christopher Gwizdala on 12/12/25.
//

import AppKit

class TabsViewController: NSViewController {
    
    private var tableView: NSTableView!
    private var sortPopUp: NSPopUpButton!
    private var searchField: NSSearchField!
    
    private var tabs: [TabItem] = []
    private var displayedTabs: [TabItem] = []
    private var filteredTabs: [TabItem] = []
    private var currentSortMode: SortMode = .mostRecent
    private var currentSortColumn: String? = nil
    private var sortAscending: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initialize filteredTabs
        filteredTabs = displayedTabs
    }
    
    enum SortMode: String {
        case mostRecent = "Most Recent"
        case original = "Original Order"
        case device = "Device"
        case title = "Title"
    }
    
    private var noDataLabel: NSTextField?
    
    override func loadView() {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view = containerView
        
        // Create "No Data" label (initially hidden)
        let noDataLabel = NSTextField(labelWithString: "No tabs available.\n\nMake sure Full Disk Access is enabled in System Settings:\n1. System Settings → Privacy & Security → Full Disk Access\n2. Add CloudyTabsSwift.app\n3. Toggle it ON\n4. Restart the app")
        noDataLabel.alignment = .center
        noDataLabel.textColor = .secondaryLabelColor
        noDataLabel.font = NSFont.systemFont(ofSize: 13)
        noDataLabel.isHidden = true
        noDataLabel.translatesAutoresizingMaskIntoConstraints = false
        noDataLabel.maximumNumberOfLines = 0
        containerView.addSubview(noDataLabel)
        self.noDataLabel = noDataLabel
        
        NSLayoutConstraint.activate([
            noDataLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            noDataLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            noDataLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 500)
        ])
        
        // Create search field at the top
        let searchHeight: CGFloat = 32
        let searchView = NSView(frame: NSRect(x: 0, y: containerView.bounds.height - searchHeight, width: containerView.bounds.width, height: searchHeight))
        searchView.autoresizingMask = [.width, .minYMargin]
        searchView.wantsLayer = true
        searchView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        searchField = NSSearchField(frame: NSRect(x: 10, y: 4, width: containerView.bounds.width - 20, height: 24))
        searchField.autoresizingMask = [.width]
        searchField.placeholderString = "Search tabs..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.controlSize = .regular
        searchView.addSubview(searchField)
        
        containerView.addSubview(searchView)
        
        // Create toolbar with sort controls below search
        let toolbarHeight: CGFloat = 40
        let toolbarY = containerView.bounds.height - searchHeight - toolbarHeight
        let toolbarView = NSView(frame: NSRect(x: 0, y: toolbarY, width: containerView.bounds.width, height: toolbarHeight))
        toolbarView.autoresizingMask = [.width, .minYMargin]
        toolbarView.wantsLayer = true
        toolbarView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        let sortLabel = NSTextField(labelWithString: "Sort by:")
        sortLabel.frame = NSRect(x: 20, y: 10, width: 60, height: 20)
        toolbarView.addSubview(sortLabel)
        
        sortPopUp = NSPopUpButton(frame: NSRect(x: 90, y: 8, width: 150, height: 24))
        sortPopUp.addItems(withTitles: [SortMode.mostRecent.rawValue, SortMode.original.rawValue, SortMode.device.rawValue, SortMode.title.rawValue])
        sortPopUp.target = self
        sortPopUp.action = #selector(sortModeChanged(_:))
        sortPopUp.selectItem(withTitle: currentSortMode.rawValue)
        toolbarView.addSubview(sortPopUp)
        
        containerView.addSubview(toolbarView)
        
        // Create table view below toolbar and search
        let tableFrame = NSRect(x: 0, y: 0, width: containerView.bounds.width, height: containerView.bounds.height - toolbarHeight - searchHeight)
        let scrollView = NSScrollView(frame: tableFrame)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.autoresizingMask = [.width, .height]
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.rowHeight = 20
        tableView.intercellSpacing = NSSize(width: 3, height: 2)
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClick(_:))
        
        // Add columns (make them sortable)
        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Title"))
        titleColumn.title = "Title"
        titleColumn.width = 300
        titleColumn.sortDescriptorPrototype = NSSortDescriptor(key: "title", ascending: true)
        tableView.addTableColumn(titleColumn)
        
        let urlColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("URL"))
        urlColumn.title = "URL"
        urlColumn.width = 300
        urlColumn.sortDescriptorPrototype = NSSortDescriptor(key: "url", ascending: true)
        tableView.addTableColumn(urlColumn)
        
        let deviceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Device"))
        deviceColumn.title = "Device"
        deviceColumn.width = 150
        deviceColumn.sortDescriptorPrototype = NSSortDescriptor(key: "deviceName", ascending: true)
        tableView.addTableColumn(deviceColumn)
        
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Date"))
        dateColumn.title = "Last Viewed"
        dateColumn.width = 150
        dateColumn.sortDescriptorPrototype = NSSortDescriptor(key: "lastViewedTime", ascending: false)
        tableView.addTableColumn(dateColumn)
        
        // Enable column sorting
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = true
        
        scrollView.documentView = tableView
        containerView.addSubview(scrollView)
        
        // Ensure table view is properly configured
        tableView.needsLayout = true
        tableView.needsDisplay = true
        print("DEBUG: TabsViewController - table view setup complete, frame: \(tableView.frame)")
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        print("DEBUG: TabsViewController - viewDidAppear, displayedTabs count: \(displayedTabs.count)")
        tableView?.reloadData()
    }
    
    func updateTabs(_ tabs: [TabItem]?) {
        self.tabs = tabs ?? []
        print("DEBUG: TabsViewController received \(self.tabs.count) tabs")
        
        // Show/hide no data label - always update on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let hasData = !self.tabs.isEmpty
            self.noDataLabel?.isHidden = hasData
            print("DEBUG: TabsViewController - noDataLabel.isHidden = \(hasData ? "true" : "false")")
            
            // Make sure view is loaded
            if self.view.window != nil || self.view.superview != nil {
                self.applySorting()
            } else {
                // View not loaded yet, wait for it
                DispatchQueue.main.async {
                    self.applySorting()
                }
            }
        }
    }
    
    private func applyFiltering() {
        let searchText = searchField?.stringValue.lowercased() ?? ""
        
        if searchText.isEmpty {
            filteredTabs = displayedTabs
        } else {
            filteredTabs = displayedTabs.filter { tab in
                tab.title.lowercased().contains(searchText) ||
                tab.url.lowercased().contains(searchText) ||
                tab.deviceName.lowercased().contains(searchText)
            }
        }
    }
    
    private func applySorting() {
        displayedTabs = tabs
        print("DEBUG: Applying sort, displayedTabs count: \(displayedTabs.count)")
        
        // If column sorting is active, use that instead
        if let sortColumn = currentSortColumn {
            displayedTabs.sort { tab1, tab2 in
                let result: ComparisonResult
                switch sortColumn {
                case "Title":
                    result = tab1.title.compare(tab2.title)
                case "URL":
                    result = tab1.url.compare(tab2.url)
                case "Device":
                    result = tab1.deviceName.compare(tab2.deviceName)
                case "Date":
                    let time1 = tab1.lastViewedTime
                    let time2 = tab2.lastViewedTime
                    if time1 > time2 {
                        result = .orderedDescending
                    } else if time1 < time2 {
                        result = .orderedAscending
                    } else {
                        result = .orderedSame
                    }
                default:
                    result = .orderedSame
                }
                
                if result == .orderedSame {
                    return tab1.sortValue < tab2.sortValue
                }
                
                return sortAscending ? (result == .orderedAscending) : (result == .orderedDescending)
            }
        } else {
            // Use popup menu sort mode
            switch currentSortMode {
            case .mostRecent:
                displayedTabs.sort { tab1, tab2 in
                    let time1 = tab1.lastViewedTime
                    let time2 = tab2.lastViewedTime
                    if time1 > 0 && time2 > 0 {
                        return time1 > time2
                    }
                    if time1 > 0 && time2 == 0 { return true }
                    if time1 == 0 && time2 > 0 { return false }
                    return tab1.sortValue < tab2.sortValue
                }
            case .original:
                displayedTabs.sort { $0.sortValue < $1.sortValue }
            case .device:
                displayedTabs.sort { tab1, tab2 in
                    let deviceCompare = tab1.deviceName.compare(tab2.deviceName)
                    if deviceCompare != .orderedSame {
                        return deviceCompare == .orderedAscending
                    }
                    return tab1.sortValue < tab2.sortValue
                }
            case .title:
                displayedTabs.sort { tab1, tab2 in
                    let titleCompare = tab1.title.compare(tab2.title)
                    if titleCompare != .orderedSame {
                        return titleCompare == .orderedAscending
                    }
                    return tab1.sortValue < tab2.sortValue
                }
            }
        }
        
        // Apply filtering after sorting
        applyFiltering()
        
        // Reload on main thread
        if Thread.isMainThread {
            tableView?.reloadData()
            print("DEBUG: Table view reloaded on main thread, numberOfRows should be: \(filteredTabs.count)")
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.tableView?.reloadData()
                print("DEBUG: Table view reloaded, numberOfRows should be: \(self?.filteredTabs.count ?? 0)")
            }
        }
    }
    
    @objc func searchFieldChanged(_ sender: NSSearchField) {
        applyFiltering()
        tableView?.reloadData()
    }
    
    @objc func sortModeChanged(_ sender: NSPopUpButton) {
        if let selectedTitle = sender.selectedItem?.title,
           let mode = SortMode(rawValue: selectedTitle) {
            currentSortMode = mode
            // Clear column sort when using popup
            currentSortColumn = nil
            // Clear table sort descriptors
            tableView?.sortDescriptors = []
            applySorting()
        }
    }
}

extension TabsViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        let count = filteredTabs.count
        return count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredTabs.count else {
            return nil
        }
        let tab = filteredTabs[row]
        
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        
        // Try to reuse existing cell, or create new one
        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        
        if cellView == nil {
            // Create new cell view
            cellView = NSTableCellView()
            cellView?.identifier = identifier
            
            // Create text field if it doesn't exist
            if cellView?.textField == nil {
                let textField = NSTextField()
                textField.isEditable = false
                textField.isBezeled = false
                textField.drawsBackground = false
                textField.translatesAutoresizingMaskIntoConstraints = false
                cellView?.addSubview(textField)
                cellView?.textField = textField
                
                // Set up constraints
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                    textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4),
                    textField.topAnchor.constraint(equalTo: cellView!.topAnchor, constant: 2),
                    textField.bottomAnchor.constraint(equalTo: cellView!.bottomAnchor, constant: -2)
                ])
            }
        }
        
        guard let cell = cellView else {
            print("DEBUG: tableView viewFor - failed to create cell for identifier: \(identifier.rawValue)")
            return nil
        }
        
        // Set cell content
        switch identifier.rawValue {
        case "Title":
            cell.textField?.stringValue = tab.title
            cell.textField?.textColor = .labelColor
        case "URL":
            cell.textField?.stringValue = tab.url
            cell.textField?.textColor = .secondaryLabelColor
        case "Device":
            cell.textField?.stringValue = tab.deviceName
            cell.textField?.textColor = .labelColor
        case "Date":
            if let date = tab.lastViewedDate {
                cell.textField?.stringValue = DateGrouper.formatDate(date)
            } else {
                cell.textField?.stringValue = "—"
            }
            cell.textField?.textColor = .secondaryLabelColor
        default:
            cell.textField?.stringValue = ""
        }
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }
        
        // Get column identifier from sort descriptor
        let columnIdentifier = sortDescriptor.key ?? ""
        
        // Map sort descriptor keys to column names
        var columnName: String? = nil
        switch columnIdentifier {
        case "title": columnName = "Title"
        case "url": columnName = "URL"
        case "deviceName": columnName = "Device"
        case "lastViewedTime": columnName = "Date"
        default: break
        }
        
        if let column = columnName {
            currentSortColumn = column
            sortAscending = sortDescriptor.ascending
            // Clear popup selection when using column sort
            sortPopUp?.selectItem(at: -1)
            applySorting()
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        // Handle selection changes if needed
    }
    
    @objc func tableViewDoubleClick(_ sender: NSTableView) {
        // Double-click to open tab
        let selectedRow = sender.selectedRow
        guard selectedRow >= 0 && selectedRow < filteredTabs.count else { return }
        
        let tab = filteredTabs[selectedRow]
        if let url = URL.decodeURL(tab.url) {
            NSWorkspace.shared.open(url)
        }
    }
}
