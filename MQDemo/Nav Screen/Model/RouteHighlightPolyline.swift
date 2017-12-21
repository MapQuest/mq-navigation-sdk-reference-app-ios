//
//  RouteHighlightPolyline.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import UIKit
import Mapbox

class RouteHighlightPolyline: MGLPolyline {

    enum RouteHighlightPolylineType {
        case casing
        case fill
    }
    
    var color: UIColor?
    var lineWidth: CGFloat = 0
    var type: RouteHighlightPolylineType = .fill
}
