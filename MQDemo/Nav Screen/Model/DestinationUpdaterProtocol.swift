//
//  DestinationUpdaterProtocol.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import Foundation


protocol DestinationSearchSelectionProtocol: class {
    /// Just add one single destination
    func selectedNew(destination: Destination)
}

protocol DestinationManagementProtocol : DestinationSearchSelectionProtocol {

    /// User wants to start the navigation based on the current destinations
    func startNavigation(withRoute route: MQRoute)
    
    /// Destinations was reset so clear the UI
    func clearNavigation()

    /// Update a table, or show new routes
    func refreshDestinations()
    
    /// Replace all the destinations
    func replace(destinations: [Destination])

    /// The list of destinations
    var destinations:[Destination] { get }
}

protocol TripPlanningProtocol : DestinationManagementProtocol {
    
    /// Show the attributions
    func showAttribution()
    
    var tripOptions:MQRouteOptions { get }
    
    var shouldReroute:Bool {set get}
}

//optional protocols (Swift does not support optional protocols, so an empty method implementation essentially makes one
extension TripPlanningProtocol {
    func showAttribution() { }
}
