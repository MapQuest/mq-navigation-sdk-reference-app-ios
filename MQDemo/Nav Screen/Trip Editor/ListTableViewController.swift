//
//  ListTableViewController.swift
//  MQNavigationDemo
//
//  Copyright © 2018 Mapquest. All rights reserved.
//

import UIKit

/// Generic table view controller that shows cells with a single label and allows single row selection of

class ListTableViewController: UITableViewController {
    
    // MARK: Public Properties
    
    /// Text on the cell labels to show
    var list: [String]?
    
    /// Set this index to make first selection, -1 if none
    var selectedIndex: Int = 0
    
    /// This closure is called every time user selects a new row (may be called many times if user keeps changing his mind before closing this view controller)
    var selectedBlock: ((Int) -> Void)?
    
    // MARK: Private Properties
    
    private let TitleCellIdentifier = "TitleCell"
    
    // MARK: - View
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView() // Eliminate extra separators below UITableView
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return list?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TitleCellIdentifier, for: indexPath)
        cell.textLabel?.text = list?[indexPath.row] ?? nil
        if indexPath.row == selectedIndex {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }

    // MARK: - Cell selection
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        cell.accessoryType = .checkmark
        selectedBlock?(indexPath.row)
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        cell.accessoryType = .none
    }
}
