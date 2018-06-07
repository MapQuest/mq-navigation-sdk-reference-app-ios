//
//  SearchAheadOperation.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import Foundation
import MQSearchAhead

/// Operation for Searching using the Mapquest Search Ahead SDK
class SearchAheadOperation : SearchOperation {
    
    //MARK: Private Properties
    fileprivate static let searchAheadService = MQSearchAheadService()
    fileprivate static let collections = [MQSearchAheadCollectionAirport, MQSearchAheadCollectionAddress, MQSearchAheadCollectionPOI, MQSearchAheadCollectionFranchise];
    fileprivate var results = [MQSearchAheadResult]()
    fileprivate var feedback: MQSearchAheadFeedback?
    fileprivate static let locationManager = CLLocationManager()
    fileprivate let semaphore = DispatchSemaphore(value: 0)
    
    //MARK: Public Methods
    
    override func main() {
        
        // Sometimes CLLocationManager.location is nil if you've stopped updating location, so we start it and then stop it after we use it
        SearchAheadOperation.locationManager.startUpdatingLocation()
        defer {
            SearchAheadOperation.locationManager.stopUpdatingLocation()
        }
        
        // Continue only if the operation is not cancelled, the text is over 2 characters long, and there is a location
        guard isCancelled == false, searchText.count > 1, let location = SearchAheadOperation.locationManager.location else {
            completion(nil)
            return
        }
        
        //Search Query
        let options = MQSearchAheadOptions()
        options.limit = 10
        
        SearchAheadOperation.searchAheadService.predictResults(forQuery: searchText, collections: SearchAheadOperation.collections, location: location.coordinate, options: options, success: { [weak self] searchAheadResponse in
            
            guard let strongSelf = self, strongSelf.isCancelled == false else { return }
            
            defer {
                if (searchAheadResponse.feedback) != nil {
                    strongSelf.feedback = searchAheadResponse.feedback;
                }
                strongSelf.semaphore.signal()
            }
            
            guard let results = searchAheadResponse.results else {
                strongSelf.completion(nil)
                return
            }
            
            // map the search results into our own struct to make it easier to work with in Swift and format the results into the format we want
            let newDestinations:[Destination]  = results.flatMap {
                guard let place = $0.place, let displayString = $0.displayString else { return nil }
                let destination = Destination(place: place)
                
                // The name is sometimes duplicated in the display string so we want to substring the address out of the display string
                if let name = $0.name, let nameRange = displayString.range(of: name) {
                    //we advance by 2 to cover the ", "
                    let fromIndex = displayString.index(nameRange.upperBound, offsetBy: 2)
                    let address = String(displayString[fromIndex...])
                    destination.displayTitle = name
                    destination.displaySubtitle = address
                }
                
                return destination
            }
            
            strongSelf.completion(newDestinations)
            
            }, failure: { [weak self] error in
                defer { self?.semaphore.signal() }
                
                self?.completion(nil)
                
                print(error);
            });
        
        // Don't let the operation close without the asynchronous calls finishing
        _ = semaphore.wait(timeout: .now() + 10)
    }
}
