//
//  Destinations.swift
//  MQNavigationTestHarness
//
//  Copyright © 2017 MapQuest. All rights reserved.
//

import CoreLocation
import Foundation
import Mapbox
import MQCore

/// This is a debugging property to allow the Demo app to route using MQIDs or only display lat/longs
var allowMQIDRouting = true

/// Destination class designed to be usable for maps and displayable table views
class Destination: MQPlace, MGLAnnotation, MQRouteDestination {
    
    struct Constants {
        static let displayTitle = "displayTitle"
        static let displaySubtitle = "displaySubtitle"
        static let favoriteType = "favoriteType"
    }
    
    convenience init(place: MQPlace) {
        self.init()
        geoAddress = place.geoAddress
        title = place.title
        subtitle = place.subtitle
        coordinate = place.coordinate
        isNavigable = place.isNavigable
        displayTitle = title ?? ""
        displaySubtitle = subtitle
    }
    
    convenience init(title: String, subtitle: String?, routeableLocation: CLLocationCoordinate2D, reached: Bool) {
        self.init()
        
        self.title = title
        self.subtitle = subtitle ?? ""
        self.coordinate = routeableLocation
        self.routeableLocation = CLLocation(latitude: routeableLocation.latitude, longitude: routeableLocation.longitude)
        self.reached = reached
        
        displayTitle = title
        displaySubtitle = subtitle
    }
    
    var displayTitle: String = ""
    var displaySubtitle: String?
    var reached = false
    var favoriteType: MQDemoOptions.SearchResultType = .place
    
    /// The location we use should either be the display location or the routeable version
    /// When we pass Destinations to the MQRouteRequest class, its going to ask for the "location" property if MQID is empty
    var location: CLLocation {
        if let routeableLocation = routeableLocation {
            return routeableLocation
        }
        return CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
    }

    /// A routeable location that we can store from geocoding or from dropping a pin on a map
    var routeableLocation : CLLocation?
    
    // MARK: NSCoding
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(displayTitle, forKey: Constants.displayTitle)
        aCoder.encode(displaySubtitle, forKey: Constants.displaySubtitle)
        aCoder.encode(favoriteType.rawValue, forKey: Constants.favoriteType)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        if let aString = aDecoder.decodeObject(forKey: Constants.displayTitle) as? String {
            displayTitle = aString
        }
        if let aString = aDecoder.decodeObject(forKey: Constants.displaySubtitle) as? String {
            displaySubtitle = aString
        }
        if let aString = aDecoder.decodeObject(forKey: Constants.favoriteType) as? String, let type = MQDemoOptions.SearchResultType(rawValue: aString) {
            favoriteType = type
        }
    }
    
    // Allowable Inits
    override init() {
        super.init()
    }
    
    override init!(geoAddress: MQGeoAddress!) {
        super.init(geoAddress: geoAddress)
    }
    override init!(geoAddressDict geoDict: [AnyHashable: Any]!) {
        super.init(geoAddressDict: geoDict)
    }
}
