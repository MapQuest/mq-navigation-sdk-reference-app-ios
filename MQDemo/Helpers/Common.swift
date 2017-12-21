//
//  Common.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

extension CLLocationSpeed {
    var milesPerHour : Double {
        return self * MPS_TO_MPH + 0.5
    }
}

func duration(forRouteTime routeTime: TimeInterval) -> String? {
    guard routeTime >= 0, routeTime < (99 * 60 * 60) else {
        return nil
    }
    
    // Divide the interval by 3600 and keep the quotient and remainder
    let h = div(Int32(routeTime), 3600)
    let hours = h.quot
    // Divide the remainder by 60; the quotient is minutes, the remainder
    // is seconds.
    let m = div(h.rem, 60)
    var minutes = m.quot
    
    if hours == 0, minutes == 0 {
        minutes = 1
    }
    
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    
    var components = DateComponents()
    components.hour = Int(hours)
    components.minute = Int(minutes)
    
    return formatter.string(from: components)
}


//MARK: -
extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let deltaX = point.x - self.x
        let deltaY = point.y - self.y
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
}

//MARK: - displayableVersionString
var displayableVersionString : String = {
    let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
    let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
    return "\(shortVersion!) (\(bundleVersion!))"
}()

//MARK: -
func descriptiveLabel(forDistance distance: CLLocationDistance) -> String {
     return MKDistanceFormatter().build({ (formatter) in
        formatter.unitStyle = .abbreviated
    }).string(fromDistance: distance)
}

//MARK: - Buildable protocol that allows you to add initialization/setup code on initializing an instance
protocol Buildable: class {}
extension Buildable {
    @discardableResult func build(_ transform: (Self) -> Void) -> Self {
        transform(self)
        return self
    }
}

//MARK: - Buildable
extension NSObject: Buildable {}

//MARK: -
extension UIAlertController {
    convenience init(title: String?, message: String?, preferredStyle: UIAlertControllerStyle, actions: [UIAlertAction]) {
        self.init(title: title, message: message, preferredStyle: preferredStyle)
        for action in actions {
            addAction(action)
        }
    }
    
    static var continueActionNil = UIAlertAction(title: "Continue", style: .default, handler: nil)
    static var cancelActionNil = UIAlertAction(title: "Cancel", style: .default, handler: nil)
}

//MARK: Little utility to programatically swipe a table cell
extension UITableView {
    func animateRevealHideAction(indexPath: IndexPath) {
        guard let cell = self.cellForRow(at: indexPath) else { return }
        
        // Should be used in a block
        var swipeLabel: UILabel? = UILabel(frame: CGRect(x: cell.bounds.size.width, y: 0, width: 200, height: cell.bounds.size.height))
        
        swipeLabel!.text = "  Swipe Me";
        swipeLabel!.backgroundColor = .red
        swipeLabel!.textColor = .white
        cell.addSubview(swipeLabel!)
        
        UIView.animate(withDuration: 1.0, animations: {
            cell.frame = CGRect.init(x: cell.frame.origin.x - 100, y: cell.frame.origin.y, width: cell.bounds.size.width + 100, height: cell.bounds.size.height)
        }) { (finished) in
            UIView.animate(withDuration: 1.0, animations: {
                cell.frame = CGRect.init(x: cell.frame.origin.x + 100, y: cell.frame.origin.y, width: cell.bounds.size.width - 100, height: cell.bounds.size.height)
            }, completion: { (finished) in
                swipeLabel?.removeFromSuperview()
                swipeLabel = nil;
            })
        }
    }

}

