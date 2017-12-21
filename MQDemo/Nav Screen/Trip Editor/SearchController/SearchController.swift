//
//  SearchController.swift
//  MQNavigationDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import Foundation

protocol SearchParentProtocol : class {
    weak var tableView: UITableView! { get }
    var displayableDestinations : [Destination] { get set }
    var shouldDisplayFavorites : Bool { get }
    func clearSearchResults()
}

extension SearchParentProtocol {
    func clearSearchResults() {
        displayableDestinations.removeAll()
        defer {
            tableView.reloadData()
        }
        
        guard shouldDisplayFavorites else { return }
        
        let options = MQDemoOptions.shared
        if let place = options.homePlace {
            displayableDestinations.append(place)
        }
        if let place = options.workPlace {
            displayableDestinations.append(place)
        }
        if let place = options.parkingPlace {
            displayableDestinations.append(place)
        }
        
        // now check for MRU
        guard let mruDestinations = options.mostRecentlyUsedDestinations else { return }
        displayableDestinations.append(contentsOf: mruDestinations)
    }
}

//MARK: - UITableViewDataSource
let destinationCellIdentifier = "destination"
extension SearchParentProtocol {
    
    func numberOfRowsIn(section: Int) -> Int {
        return displayableDestinations.count
    }
    
    func cellForRowAt(indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: destinationCellIdentifier, for: indexPath)
        let destination = displayableDestinations[indexPath.row]
        
        cell.textLabel?.text = destination.displayTitle
        cell.detailTextLabel?.text = destination.displaySubtitle
        
        cell.imageView?.image = {
            switch destination.favoriteType {
            case .home: return #imageLiteral(resourceName: "home")
            case .parking:return #imageLiteral(resourceName: "parking")
            case .work:return #imageLiteral(resourceName: "work")
            case .contact: return #imageLiteral(resourceName: "contact")
            case .event: return #imageLiteral(resourceName: "event")
            case .mru: return #imageLiteral(resourceName: "mru")
            case .place: return nil
            }
        }()
        
        return cell
    }
    
    func trailingSwipeActionsConfigurationForRowAt(indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let destination = displayableDestinations[indexPath.row]
        
        guard destination.favoriteType.isFavorite == false else {
            
            let removeAction: UIContextualAction = {
                let action = UIContextualAction(style: .destructive, title: "Clear") {
                    (contextAction: UIContextualAction, sourceView: UIView, completionHandler: (Bool) -> Void) in
                    
                    MQDemoOptions.shared.removePlace(type: destination.favoriteType)
                    self.displayableDestinations.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    completionHandler(true)
                }
                return action
            }()
            return UISwipeActionsConfiguration(actions: [removeAction])
        }
        
        let setWorkAction: UIContextualAction = {
            let action = UIContextualAction(style: .normal, title: "Set Work") {
                (contextAction: UIContextualAction, sourceView: UIView, completionHandler: (Bool) -> Void) in
                MQDemoOptions.shared.workPlace = destination
                self.clearSearchResults()
                completionHandler(true)
            }
            action.image = #imageLiteral(resourceName: "work")
            action.backgroundColor = .blue
            return action
        }()
        
        let setParkingAction: UIContextualAction = {
            let action = UIContextualAction(style: .normal, title: "Set Parking") {
                (contextAction: UIContextualAction, sourceView: UIView, completionHandler: (Bool) -> Void) in
                MQDemoOptions.shared.parkingPlace = destination
                self.clearSearchResults()
                completionHandler(true)
            }
            action.image = #imageLiteral(resourceName: "parking")
            action.backgroundColor = .gray
            return action
        }()
        
        let setHomeAction: UIContextualAction = {
            
            let action = UIContextualAction(style: .normal, title: "Set Home") {
                (contextAction: UIContextualAction, sourceView: UIView, completionHandler: (Bool) -> Void) in
                MQDemoOptions.shared.homePlace = destination
                self.clearSearchResults()
                completionHandler(true)
            }
            action.image = #imageLiteral(resourceName: "home")
            action.backgroundColor = .brown
            return action
        }()
        
        return UISwipeActionsConfiguration(actions: [setWorkAction, setParkingAction, setHomeAction]).build {
            $0.performsFirstActionWithFullSwipe = false
        }
    }
}

class SearchController : NSObject {
    private weak var parentVC: SearchParentProtocol?
    private var finalDestinations = [Destination]()
    private let searchQueue : OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Search Operation"
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    convenience init(parent: SearchParentProtocol) {
        self.init()
        parentVC = parent
    }

    func search(_ searchText: String) {
        
        func updateParent(withDestinations destinations: [Destination]?) {
            
            if let destinations = destinations {
                finalDestinations.append(contentsOf: destinations)
            }
            
            //update the search
            OperationQueue.main.addOperation { [weak self] in
                guard let strongSelf = self, let parentVC = strongSelf.parentVC else { return }

                parentVC.displayableDestinations = strongSelf.finalDestinations
                parentVC.tableView.reloadData()
            }
        }
       
        //Stop and clear
        cancel()
        parentVC?.clearSearchResults()
        
        guard searchText.count > 2 else { return }

        let searchAheadOp = SearchAheadOperation(searchText: searchText) { newDestinations in
            updateParent(withDestinations: newDestinations)
        }
 
        let contactsSearch = ContactsSearchOperation(searchText: searchText) { newDestinations in
            updateParent(withDestinations: newDestinations)
        }
        
        let finalQueue = BlockOperation { [weak self] in
            // if its the first time we've shown data - lets show them we can swipe
            guard let strongSelf = self, MQDemoOptions.shared.showSwipeMe == false, strongSelf.finalDestinations.count > 0 else { return }
            NSObject.cancelPreviousPerformRequests(withTarget: strongSelf, selector: #selector(strongSelf.showUserSwipe), object: nil)
            strongSelf.perform(#selector(strongSelf.showUserSwipe), with: nil, afterDelay: 1)
        }
        finalQueue.addDependency(searchAheadOp)
        finalQueue.addDependency(contactsSearch)
 
        searchQueue.addOperations([searchAheadOp, contactsSearch, finalQueue], waitUntilFinished: false)
    }
    
    func cancel() {
        searchQueue.cancelAllOperations()
        finalDestinations.removeAll()
    }
    
    @objc func showUserSwipe() {
        guard let parentVC = self.parentVC else { return }
        parentVC.tableView.animateRevealHideAction(indexPath: IndexPath(row: 0, section: 0))
        MQDemoOptions.shared.showSwipeMe = true
    }
}


/// Operation Subclass used by the regular SearchOperations
class SearchOperation : Operation {
    
    typealias SearchOpCompletionBlock = ([Destination]?) -> Void
    
    var searchText = ""
    var completion : SearchOpCompletionBlock!
    
    //MARK: Public Methods
    convenience init(searchText: String, completionBlock: @escaping SearchOpCompletionBlock) {
        self.init()
        
        self.searchText = searchText
        self.completion = completionBlock
    }
}

