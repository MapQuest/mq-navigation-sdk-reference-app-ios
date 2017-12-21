//
//  TripSearchViewController.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import UIKit

/// Embedded View Controller that gives the user the ability to pick a destination
/// We use the MQSearchAhead framework to provide the results

class TripSearchViewController: UIViewController, SearchParentProtocol {

    //MARK: Interface Builder Outlets
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.isHidden = true
        }
    }
    @IBOutlet weak var searchBar: UISearchBar!

    //MARK: Public Propertyies
    var displayableDestinations = [Destination]()
    var heightLayoutConstraint : NSLayoutConstraint?
    weak var delegate : DestinationSearchSelectionProtocol?
    var shouldDisplayFavorites = true

    //MARK: Private Properties
    private lazy var searchController = SearchController(parent: self)

    private var active : Bool = false {
        didSet {
            tableView.isHidden = !active
            heightLayoutConstraint?.constant = active ? 200:56
        }
    }
}

//MARK: - UISearchBarDelegate
extension TripSearchViewController: UISearchBarDelegate {
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.showsCancelButton = true
        self.active = true
        clearSearchResults()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchController.search(searchText)
        self.active = true
        
        if searchText.count == 0 {
            clearSearchResults()
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchController.cancel()
        searchBar.showsCancelButton = false
        OperationQueue.main.addOperation { [weak self] in
            
            guard let strongSelf = self else { return }
            
            strongSelf.clearSearchResults()
            
            strongSelf.active = false
        }
    }
}

//MARK: - UITableViewDataSource
extension TripSearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numberOfRowsIn(section: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cellForRowAt(indexPath: indexPath)
    }
}

//MARK: - UITableViewDelegate
extension TripSearchViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return trailingSwipeActionsConfigurationForRowAt(indexPath: indexPath)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let destination = displayableDestinations[indexPath.row]
        delegate?.selectedNew(destination: destination)
        MQDemoOptions.shared.addMRU(destination: destination)
        
        searchBar.text = ""
        active = false
    }
}
