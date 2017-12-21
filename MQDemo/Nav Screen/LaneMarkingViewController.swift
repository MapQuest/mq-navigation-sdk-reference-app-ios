//
//  LaneMarkingViewController.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import UIKit
import MQNavigation

class LaneMarkingViewController: UIViewController {

    //MARK: - Interface Builder Outlets
    @IBOutlet weak var laneIcon0 : UIImageView!
    @IBOutlet weak var laneIcon0Width : NSLayoutConstraint!
    @IBOutlet weak var laneIcon1 : UIImageView!
    @IBOutlet weak var laneIcon1Width : NSLayoutConstraint!
    @IBOutlet weak var laneIcon2 : UIImageView!
    @IBOutlet weak var laneIcon2Width : NSLayoutConstraint!
    @IBOutlet weak var laneIcon3 : UIImageView!
    @IBOutlet weak var laneIcon3Width : NSLayoutConstraint!
    @IBOutlet weak var laneIcon4 : UIImageView!
    @IBOutlet weak var laneIcon4Width : NSLayoutConstraint!
    @IBOutlet weak var laneIcon5 : UIImageView!
    @IBOutlet weak var laneIcon5Width : NSLayoutConstraint!
    
    @IBOutlet weak var laneSpacer0Width : NSLayoutConstraint!
    @IBOutlet weak var laneSpacer1Width : NSLayoutConstraint!
    @IBOutlet weak var laneSpacer2Width : NSLayoutConstraint!
    @IBOutlet weak var laneSpacer3Width : NSLayoutConstraint!
    @IBOutlet weak var laneSpacer4Width : NSLayoutConstraint!

    private(set) var hasLanesToShow : Bool = false
    
    //MARK: Private properties
    var laneIcons : [UIImageView]!
    var laneIconWidths : [NSLayoutConstraint]!
    var laneSpacerWidths : [NSLayoutConstraint]!
    
    //MARK: - Public Methods
    func update(laneGuidance: [MQLaneInfo]?) {
        // Hacky way to quickly get this working without doing complicated spacing and rendering myself. Limited to six lanes. Takes advantage of the constraint system.
        
        // Only show the widget if all the lanes have a valid icon associated with them
        
        guard let laneGuidance = laneGuidance, laneGuidance.isEmpty == false, laneGuidance.count < 7 else {
            hasLanesToShow = false
            return
        }
        

        for (index, info) in laneGuidance.enumerated() {
            var icon : UIImage?
            laneIcons[index].tintColor = nil
            
            if info.laneMarking > 0, info.laneHighlights > 0 {
                // Lane is recommended. See if we have an exact icon
                icon = UIImage(named: "lm_\(info.laneMarking)_\(info.laneHighlights)")
            } else if info.laneMarking > 0 {
                // Lane is not recommended.
                icon = UIImage(named: "lm_\(info.laneMarking)")

            } else if info.laneMarking > 0 {
                // Don't know about this lane. Use don't know image
                icon = UIImage(named: "1m_0")
            }
            
            guard icon != nil else { continue }
            laneIcons[index].image = icon
            laneIconWidths[index].constant = 40.0
            
            if index > 0 {
                laneSpacerWidths[index - 1].constant = 14.0
            }
        }
        
        for index in laneGuidance.count..<laneIcons.count {
            laneIcons[index].image = nil
            laneIconWidths[index].constant = 0.0
            laneIcons[index].tintColor = nil
            
            if index > 0 {
                laneSpacerWidths[index - 1].constant = 0
            }
        }
        
        view.layoutIfNeeded()
        hasLanesToShow = true
    }
    
    //MARK: Internal Controller
    override func viewDidLoad() {
        super.viewDidLoad()
        
        laneIcons = [laneIcon0, laneIcon1, laneIcon2, laneIcon3, laneIcon4, laneIcon5];
        laneIconWidths = [laneIcon0Width, laneIcon1Width, laneIcon2Width, laneIcon3Width, laneIcon4Width, laneIcon5Width];
        laneSpacerWidths = [laneSpacer0Width, laneSpacer1Width, laneSpacer2Width, laneSpacer3Width, laneSpacer4Width];
    }
}
