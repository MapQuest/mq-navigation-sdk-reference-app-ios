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

/// Destination class designed to be usable for maps and displayable table views
class Destination: MQPlace, MGLAnnotation {
    
    convenience init(place: MQPlace) {
        self.init()
        geoAddress = place.geoAddress
        title = place.title
        subtitle = place.subtitle
        coordinate = place.coordinate
        isNavigable = place.isNavigable
        
        displayTitle = title
        displaySubtitle = subtitle
    }
    
    convenience init(title: String, subtitle: String?, coordinate: CLLocationCoordinate2D, reached: Bool) {
        self.init()
        
        self.title = title
        self.subtitle = subtitle ?? ""
        self.coordinate = coordinate
        self.reached = reached
        
        displayTitle = title
        displaySubtitle = subtitle
    }
    
    var displayTitle: String = ""
    var displaySubtitle: String?
    var reached = false
    var favoriteType: MQDemoOptions.SearchResultType = .place
    
    var location: CLLocation {
        return CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
    }
    
    // MARK: NSCoding
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(displayTitle, forKey: "displayTitle")
        aCoder.encode(displaySubtitle, forKey: "displaySubtitle")
        aCoder.encode(favoriteType.rawValue, forKey: "favoriteType")
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        if let aString = aDecoder.decodeObject(forKey: "displayTitle") as? String {
            displayTitle = aString
        }
        if let aString = aDecoder.decodeObject(forKey: "displaySubtitle") as? String {
            displaySubtitle = aString
        }
        if let aString = aDecoder.decodeObject(forKey: "favoriteType") as? String, let type = MQDemoOptions.SearchResultType(rawValue: aString) {
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
