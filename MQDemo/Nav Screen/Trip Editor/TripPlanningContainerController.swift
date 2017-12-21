//
//  TripPlanningContainerController.swift
//  MQDemo
//
//  Copyright © 2017 MapQuest. All rights reserved.
//

import UIKit

/// Container view controller for the TripDetailView controller
class TripPlanningContainerController: UIViewController, DestinationSearchSelectionProtocol {
 
    //MARK: Interface Builder Outlets
    @IBOutlet weak var searchHeightConstraint: NSLayoutConstraint!

    //MARK: Public Propertyies
    weak var delegate: TripPlanningProtocol?
    
    private var tripDetailViewController : TripDetailViewController?

    //MARK: View Controller Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        // The search screen needs to expand itself when showing the table view
        if let searchController = segue.destination as? TripSearchViewController {
            searchController.heightLayoutConstraint = searchHeightConstraint
            searchController.delegate = self
        } else if let destination = segue.destination as? TripDetailViewController {
            destination.delegate = delegate
            tripDetailViewController = destination
        }
    }
    
    //MARK: DestinationSearchSelectionProtocol
    func selectedNew(destination: Destination) {
        tripDetailViewController?.selectedNew(destination: destination)
    }
    
    //MARK: Actions
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func goRoute(_ sender: UIBarButtonItem) {
        dismiss(animated: true) {
            guard let delegate = self.delegate else { return }
            guard let destinations = self.tripDetailViewController?.destinations, destinations.count > 0 else {
                delegate.clearNavigation()
                return
            }
            
            delegate.replace(destinations: destinations)
            delegate.refreshDestinations()
        }
    }
}
