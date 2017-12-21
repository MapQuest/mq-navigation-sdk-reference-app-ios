//
//  RouteTimeAnnotation.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import UIKit
import Mapbox

class RouteNameAnnotation: MGLPointAnnotation {
    var route: MQRoute?
}

// MARK: MGLAnnotationView subclass
class RouteTimeAnnotationView: MGLAnnotationView {
    
    var time = "" {
        didSet {
            let textLayer = UILabel(frame: CGRect.zero)
            textLayer.text = time
            textLayer.textAlignment = .center
            textLayer.textColor = .white
            textLayer.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            self.textLayer = textLayer
            addSubview(textLayer)
        }
    }
    
    func size(forText text: String) -> CGSize {
        let drawingAttributes = [NSAttributedStringKey.font:UIFont.systemFont(ofSize: 11, weight: .medium)]
        var size = text.size(withAttributes: drawingAttributes)
        size.width += 6
        size.height += 4
        return size
    }
    
    var textLayer : UILabel?
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        setSelectionColor()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Force the annotation view to maintain a constant size when the map is tilted.
        scalesWithViewingDistance = false
        
        // Use CALayer’s corner radius to turn this view into a circle.
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.cgColor
        
        if let textLayer = textLayer {
            textLayer.frame = bounds
        }
    }
    
    fileprivate func setSelectionColor() {
        backgroundColor = isSelected ? #colorLiteral(red: 0.1921568627, green: 0.537254902, blue: 0.7725490196, alpha: 0.9499064701):#colorLiteral(red: 0.5411764706, green: 0.7960784314, blue: 0.968627451, alpha: 0.7452409771)
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        setSelectionColor()
    }
}
