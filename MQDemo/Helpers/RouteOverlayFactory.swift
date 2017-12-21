//
//  RouteAnnotator.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import Foundation

class RouteOverlayFactory {
    
    //MARK: Public Properties
    let casingActiveWidth : CGFloat = 8.0
    let casingInactiveWidth : CGFloat = 8.0
    let fillActiveWidth : CGFloat = 8.0
    let fillInactiveWidth : CGFloat = 8.0
    
    var lastCompletedRouteLeg: MQRouteLeg?
    
    //MARK: - Public Methods
    func polylines(forRouteLegs routeLegs: [MQRouteLeg], isActive:Bool) -> [RouteHighlightPolyline] {
        var routeHighlights = [RouteHighlightPolyline]()
        
        func color(forTrafficConditions conditionStatus: MQCongestionSeverity, isActive: Bool) -> UIColor {
            switch conditionStatus {
            case .stopAndGo: return isActive ? TrafficColor.stopAndGo : TrafficColor.stopAndGoInActive
            case .freeFlow: return isActive ? TrafficColor.freeFlow : TrafficColor.freeFlowInActive
            case .slow: return isActive ? TrafficColor.slow : TrafficColor.slowInActive
            case .closed: return isActive ? TrafficColor.closed : TrafficColor.closedInActive
            default: return isActive ? TrafficColor.unknown : TrafficColor.unknownInactive
            }
        }
     
        //highlight the route
        for routeLeg in routeLegs {
            
            // We don't want to draw routes we've already passed
            if let lastCompletedRouteLeg = self.lastCompletedRouteLeg, routeLeg === lastCompletedRouteLeg {
                continue
            }
           
            let casing = RouteHighlightPolyline(coordinates: routeLeg.shape.coordinates(), count: routeLeg.shape.coordinateCount())
            casing.title = "routeHighlightCasing"
            casing.color = isActive ? RouteColors.casingColor : RouteColors.casingColor.withAlphaComponent(0.5)
            casing.lineWidth = isActive ? casingActiveWidth:casingInactiveWidth
            
            let filling = RouteHighlightPolyline(coordinates: routeLeg.shape.coordinates(), count: routeLeg.shape.coordinateCount())
            filling.title = "routeHighlightFilling"
            filling.type = .fill
            filling.color = isActive ? RouteColors.theDefault : RouteColors.theDefault.withAlphaComponent(0.5)
            filling.lineWidth = isActive ? fillActiveWidth:fillInactiveWidth

            routeHighlights.append(casing)
            routeHighlights.append(filling)
        }
        
        //highlight the traffic
        for routeLeg in routeLegs {
            
            // We don't want to draw routes we've already passed
            if let lastCompletedRouteLeg = self.lastCompletedRouteLeg, routeLeg === lastCompletedRouteLeg {
                continue
            }
            for congestion in routeLeg.traffic.conditions {
                if congestion.severity == .freeFlow { continue }
                
                guard let pair = MQShapeSegmenter.segmentIndividualSpan(congestion, in: routeLeg.shape), pair.coordinateArray.count > 0 else { continue }
                let array = pair.coordinateArray
                
                let casing = RouteHighlightPolyline(coordinates: array.coordinateArray, count: array.count)
                casing.title = "trafficFlowHighlightCasing"
                casing.color = RouteColors.casingColor
                casing.lineWidth = isActive ? casingActiveWidth:casingInactiveWidth
                
                let filling = RouteHighlightPolyline(coordinates: array.coordinateArray, count: array.count)
                filling.title = "trafficFlowHighlightFilling"
                filling.type = .fill
                filling.color = color(forTrafficConditions: congestion.severity, isActive: isActive)
                filling.lineWidth = isActive ? fillActiveWidth:fillInactiveWidth

                routeHighlights.append(casing)
                routeHighlights.append(filling)
           }
        }
        
        return routeHighlights
    }
}
