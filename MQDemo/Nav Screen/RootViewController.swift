//
//  RootViewController.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import UIKit
import MQNavigation
import CallKit
import Reachability
import Pulley

class RootViewController: UIViewController {

    // MARK: Interface Builder Outlets
    @IBOutlet weak var statusBarBlurView: UIVisualEffectView!
    @IBOutlet weak var navHatView: UIView!
    @IBOutlet weak var navHatViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var navHatDistanceLabel: UILabel!
    @IBOutlet weak var navHatManeuverLabel: UILabel!
    @IBOutlet weak var navHatManeuverIcon: UIImageView!
    @IBOutlet weak var navHatManeuverTypeTextLabel: UILabel!
    @IBOutlet weak var navHatDebugCounter: UILabel!
    @IBOutlet weak var turnLaneView: UIView! {
        didSet {
            turnLaneView.isHidden = true
        }
    }
    @IBOutlet weak var turnLaneTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var speedLimitView: UIView! {
        didSet {
            speedLimitView.alpha = 0
        }
    }
    @IBOutlet weak var speedLimitSpeed: UILabel!
    @IBOutlet weak var recenterButton: UIButton!
    @IBOutlet weak var errorBarView: UIView! {
        didSet {
            errorBarView.isHidden = true
        }
    }
    @IBOutlet weak var errorBarLabel: UILabel!
    @IBOutlet weak var errorBarBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomBarView: UIView! {
        didSet {
            bottomBarView.alpha = 0.0
        }
    }
    @IBOutlet weak var bottomBarMainLabel: UILabel!
    @IBOutlet weak var bottomBarSecondaryLabel: UILabel!
    @IBOutlet weak var bottomBarFinalLabel: UILabel!
    @IBOutlet weak var bottomBarStopButton: UIButton!
    @IBOutlet weak var bottomBarListButton: UIButton!
    @IBOutlet weak var bottomBarBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var soundButton: UIButton! {
        didSet {
            soundButton.setImage(MQDemoOptions.shared.promptsAudio.image, for: .normal)
        }
    }
    
    @IBOutlet weak var floatingButtons: UIView!
    @IBOutlet weak var infoButton: UIButton!
    @IBOutlet weak var floatingButtonsTopConstraint: NSLayoutConstraint!
    
    // MARK: Navigation Controller
    var navViewController: NavViewController!
    
    // MARK: Private Properties
    private var laneMarkingViewController: LaneMarkingViewController!
    
    private lazy var reachability: Reachability? = {
        guard let reach = Reachability(hostName: "www.mapquest.com") else { return nil }
        reach.reachableBlock = { [weak self] _ in
            OperationQueue.main.addOperation {
                guard let strongSelf = self else { return }
                strongSelf.updateWarnings()
            }
        }
        reach.unreachableBlock = reach.reachableBlock
        reach.startNotifier()
        return reach
    }()
    
    fileprivate var defaultETAColor: UIColor!
    fileprivate var navWarnings = [String]()
    fileprivate var currentDestination : Destination? {
        return navViewController.currentDestination
    }
    
    // MARK: - View Controller Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup some defaults
        bottomBarBottomConstraint.constant = -1.0 * bottomBarView.frame.height
        defaultETAColor = bottomBarMainLabel.textColor
        errorBarBottomConstraint.constant = -1.0 * errorBarView.frame.height
        turnLaneTopConstraint.constant = -1.0 * turnLaneView.frame.height
        navHatViewTopConstraint.constant = -1.0 * navHatView.frame.height
        
        // setup the Status Bar Constraints especially so that it works properly for iPhone X
        //top to topview
        let topConstraint = NSLayoutConstraint(item: statusBarBlurView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: 0)
        
        // bottom constraint
        let bottomConstraint: NSLayoutConstraint = {
            if #available(iOS 11.0, *) {
                return NSLayoutConstraint(item: statusBarBlurView, attribute: .bottom, relatedBy: .equal, toItem: view.safeAreaLayoutGuide, attribute: .top, multiplier: 1, constant: 0)
            } else {
                // Fallback on earlier versions
                return NSLayoutConstraint(item: statusBarBlurView, attribute: .bottom, relatedBy: .equal, toItem: self.topLayoutGuide, attribute: .bottom, multiplier: 1, constant: 0)
            }
        }()
        view.addConstraints([topConstraint, bottomConstraint])
        
        clearUI()
    }
    
    // This project uses several embedded views that target other view controllers.
    // This allows us to be able to retain references to those view controllers
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        // Since we are using embedded view controllers in the storyboard, we are setting the properties here
        if let destination = segue.destination as? NavViewController {
            navViewController = destination
            navViewController.delegate = self
        } else if let destination = segue.destination as? LaneMarkingViewController {
            laneMarkingViewController = destination
        } else if let instructionsPageController = (segue.destination as? UINavigationController)?.topViewController as? InstructionsPageController {
            // Setup the destination on the Instructions screen
            
            guard let route = navViewController.selectedRoute, let routeLeg = navViewController.currentRouteLeg else {
                return
            }
            
            func makeInstructionsVC(showingLeg leg: MQRouteLeg) -> InstructionsViewController {
                func destinationForLeg() -> Destination? {
                    guard destinations.count > 0, let indexOfRouteLeg = route.legs.index(of: leg) else { return nil}
                    return destinations[indexOfRouteLeg]
                }

                guard let destination = destinationForLeg(), let instructionsVC = storyboard?.instantiateViewController(withIdentifier: "InstructionsViewController") as? InstructionsViewController else { fatalError("Storyboard is missing the Instructions") }
                
                instructionsVC.currentRouteLeg = leg
                instructionsVC.route = route
                
                let highways: String = {
                    switch navViewController.tripOptions.highways {
                    case .avoid:    return "AVOID HIGHWAYS"
                    case .disallow: return "DISALLOW HIGHWAYS"
                    default:        return ""
                    }
                }()
                let tolls: String = {
                    switch navViewController.tripOptions.tolls {
                    case .avoid:    return "AVOID TOLLS"
                    case .disallow: return "DISALLOW TOLLS"
                    default:        return ""
                    }
                }()
                
                if highways.isEmpty == false, tolls.isEmpty == false {
                    instructionsVC.flagString = "\(highways) \(tolls)"
                } else if highways.isEmpty == false {
                    instructionsVC.flagString = highways
                } else if tolls.isEmpty == false {
                    instructionsVC.flagString = tolls
                }
                
                instructionsVC.displayAddress = "\(destination.title ?? "")•\(destination.subtitle ?? "")"
                return instructionsVC
            }
            
            let viewControllers = route.legs.map { makeInstructionsVC(showingLeg: $0) }
            
            instructionsPageController.pages = viewControllers
            instructionsPageController.selectedPageIndex = route.legs.index(of: routeLeg) ?? 0
        } else if let destination = segue.destination.childViewControllers.first as? TripPlanningContainerController {
            destination.delegate = self
        }
    }
    
    // MARK: Getters / Setters / Actions
    @IBAction func exitPressed(_ sender: AnyObject?) {
        
        if navViewController.state == .paused {
            self.bottomBarStopButton.setImage(#imageLiteral(resourceName: "xButton"), for: .normal)
            self.navViewController.resumeNavigation()
            return
        }
        
        // X is pressed
        let exitAction = UIAlertAction(title: "Exit Navigation", style: .destructive) { (action) in
            self.navViewController.stopNav()
        }
        let pauseAction = UIAlertAction(title: "Pause Navigation", style: .default) { (action) in
            self.navViewController.pauseNavigation()
            self.bottomBarStopButton.setImage(#imageLiteral(resourceName: "pause"), for: .normal)
        }
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet, actions: [exitAction, pauseAction, UIAlertController.cancelActionNil])
        alert.popoverPresentationController?.sourceRect = bottomBarStopButton.bounds
        alert.popoverPresentationController?.sourceView = bottomBarStopButton
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func soundPressed(_ sender: AnyObject?) {
        MQDemoOptions.shared.promptsAudio = MQDemoOptions.shared.promptsAudio.advance()
        soundButton.setImage(MQDemoOptions.shared.promptsAudio.image, for: .normal)
    }
    
    @IBAction func recenterButtonPressed(_ sender: AnyObject?) {
        navViewController.resumeUserFollowMode()
    }
    
    @IBAction func bottomBarTapped(_ sender: AnyObject?) {
        guard navViewController.state == .paused else { return }
        navViewController.resumeNavigation()
    }
    
    @IBAction func nextDestinationLabelTapped(_ sender: AnyObject?) {
        guard navViewController.isLegFinalDestination == false, let currentDestination = self.currentDestination, let nextDestinationIndex = destinations.index(of: currentDestination)?.advanced(by: 1) else { return }
        
        let nextDestinationName = destinations[nextDestinationIndex].displayTitle
        let currentDestinationAction = UIAlertAction(title: currentDestination.displayTitle, style: .default, handler: nil)
        let nextDestinationAction = UIAlertAction(title: nextDestinationName , style: .default) { (action) in
            self.navViewController.advanceRouteToNextLeg()
        }
        let alert = UIAlertController(title: "Advance Leg", message: "Go to the next leg in the route?", preferredStyle: .actionSheet, actions: [currentDestinationAction, nextDestinationAction, UIAlertController.cancelActionNil])
        alert.popoverPresentationController?.sourceRect = bottomBarStopButton.bounds
        alert.popoverPresentationController?.sourceView = bottomBarStopButton

        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func GPSButtonPressed(_ sender: AnyObject?) {
        navViewController.centerMapOnUser()
    }
    
    // Allows you to bring up any special menu as a result of a long press
    // Useful for debugging purposes
    @IBAction func GPSButtonLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else {
            return
        }
        // This shows an internal debugging menu
        LoggingManager.shared.specialMenuAction(presenting: self, view: sender.view!)
    }
    
    // MARK: Private Methods
    fileprivate func clearUI() {
        navHatManeuverLabel.text = ""
        navHatDistanceLabel.text = ""
        navHatManeuverIcon.image = nil
        navHatManeuverTypeTextLabel.text = "   "
        errorBarLabel.text = ""
        bottomBarMainLabel.text = ""
        bottomBarSecondaryLabel.text = ""
        bottomBarFinalLabel.text = ""
        navHatManeuverLabel.text = ""
        update(laneGuidance: nil)
        navWarnings.removeAll()
        updateWarnings()
        recenterButton.transform = CGAffineTransform(scaleX: 0, y: 0)
        
        if let drawer = self.parent as? PulleyViewController {
            drawer.setDrawerPosition(position: .collapsed, animated:true)
        }
    }
    
    /// Update the warnings screen with reachability or navigation warnings
    fileprivate func updateWarnings() {
        let reachable = reachability?.currentReachabilityStatus() != .NotReachable
        let errorString: String = {
            if reachability != nil, reachable == false {
                return "No Data"
            } else if navWarnings.count > 0 {
                return navWarnings.joined(separator: " • ")
            }
            return ""
        }()
        
        if errorString.isEmpty == false, errorBarView.isHidden {
            errorBarView.isHidden = false
            UIView.animate(withDuration: 0.25) {
                self.errorBarBottomConstraint.constant = 0
                self.view.layoutIfNeeded()
            }
        } else if errorString.isEmpty, errorBarView.isHidden == false {
            errorBarBottomConstraint.constant = -1.0 * errorBarView.frame.height
            UIView.animate(withDuration: 0.25, animations: {
                self.view.layoutIfNeeded()
            }, completion: { _ in
                self.errorBarView.isHidden = true
            })
        }
        
        errorBarLabel.text = errorString
        
        if let _ = reachability {
            let networkStatus: SessionNetworkStatus = {
                guard reachable else {
                    
                    // check to see if they are on a phone call
                    var isOnPhoneCall: Bool {
                        let callObserver = CXCallObserver()
                        for call in callObserver.calls {
                            if call.hasEnded == false {
                                return true
                            }
                        }
                        
                        return false
                    }
                    
                    return isOnPhoneCall ? .noServiceCall : .noService
                }
                return .connected
            }()
            LoggingManager.shared.update(networkStatus: networkStatus)
        }
    }
}

// MARK: - NavViewControllerDelegate
extension RootViewController: NavViewControllerDelegate {
    
    /// Edge Insets for the navigation view to be able to zoom annotations properly
    var visibleEdgeInsets : UIEdgeInsets {
        guard let drawer = self.parent as? PulleyViewController, let searchController = drawer.drawerContentViewController as? SearchDestinationViewController else {
            return UIEdgeInsetsMake(navHatView.frame.maxY, 20, bottomBarView.frame.origin.x, 20)
        }
        return UIEdgeInsetsMake(navHatView.frame.maxY + statusBarBlurView.bounds.height, 20, searchController.partialRevealDrawerHeight(bottomSafeArea: drawer.bottomSafeSpace), 20)
    }
    
    /// If the user drops a pin, we need to bring the Start Navigation UI up
    func pinDroppedOnMap(atLocation location: CLLocationCoordinate2D) {
        guard let drawer = self.parent as? PulleyViewController else { return }
        
        navViewController.destinations.append(Destination(title: "Dropped Pin", subtitle: "", routeableLocation: location, reached: false))
        
        navViewController.refreshDestinations()
        
        if drawer.drawerPosition != .partiallyRevealed {
            drawer.setDrawerPosition(position: .partiallyRevealed, animated: true)
        }
    }
    
    /// Navigation View Controller Delegate call that navigation is starting
    /// Sets up the UI properly for a newly started navigation session
    func navigationStarting() {
        navHatManeuverLabel.text = "Go to the route…"
        navHatManeuverIcon.image = #imageLiteral(resourceName: "navatar_location")
        navHatManeuverTypeTextLabel.text = "   "
        navHatViewTopConstraint.constant = 0.0
        bottomBarBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
            self.floatingButtons.alpha = 0.0
            self.bottomBarView.alpha = 1.0
        }
        
        if let drawer = self.parent as? PulleyViewController {
            drawer.setDrawerPosition(position: .closed, animated: true)
        }
    }
    
    /// Navigation View Controller Delegate call that navigation has stopped
    /// Clears the UI back to its default state
    func navigationStopped() {
        UIView.animate(withDuration: 0.3) {
            self.speedLimitView.alpha = 0.0
        }
        
        clearUI()
        
        navHatViewTopConstraint.constant = -1.0 * navHatView.frame.height
        bottomBarBottomConstraint.constant = -1.0 * bottomBarView.frame.height
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
            self.floatingButtons.alpha = 1.0
            self.bottomBarView.alpha = 0.0
        }
    }
    
    /// Navigation View Controller Delegate call to update the next upcoming manuver distance
    func update(maneuverBarDistance distance: CLLocationDistance) {
        navHatDistanceLabel.text = distance < 0.0 ? "" : descriptiveLabel(forDistance: distance)
    }
    
    /// Navigation View Controller Delegate call to update the next upcoming manuver text and image
    func update(maneuverBarText: String, turnType: MQManeuverType, maneuverTypeText: String) {
        navHatManeuverLabel.text = maneuverBarText
        navHatManeuverIcon.image = MQManeuver.image(maneuverType: turnType)
        navHatManeuverTypeTextLabel.text = maneuverTypeText
    }
    
    /// Navigation View Controller Delegate call to display Lane Guidance for an upcoming turn
    func update(laneGuidance: [MQLaneInfo]?) {
        laneMarkingViewController.update(laneGuidance: laneGuidance)
        
        if laneMarkingViewController.hasLanesToShow {
            if turnLaneView.isHidden {
                turnLaneView.isHidden = false
                UIView.animate(withDuration: 0.25) {
                    self.turnLaneTopConstraint.constant = 0.0
                    self.view.layoutIfNeeded()
                }
            }
        } else {
            UIView.animate(withDuration: 0.25, animations: {
                self.turnLaneTopConstraint.constant = -1.0 * self.turnLaneView.frame.height
                self.view.layoutIfNeeded()
            }, completion: { _ in
                self.turnLaneView.isHidden = true
            })
        }
    }
    
    /// Navigation View Controller Delegate call to update the ETA
    func update(currentLegETA: TimeInterval, finalETA: TimeInterval, distanceRemaining: CLLocationDistance, trafficOverview: MQTrafficOverview) {

        let shortDateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            let shortDateFormat = DateFormatter.dateFormat(fromTemplate: "h:mm a", options: 0, locale: Locale.current)
            formatter.dateFormat = shortDateFormat
            return formatter
        }()
        
        bottomBarMainLabel.text = duration(forRouteTime: currentLegETA)
        bottomBarMainLabel.textColor = {
            switch trafficOverview {
            case .light:
                return TrafficColor.lightTraffic
            case .medium:
                return TrafficColor.mediumTraffic
            case .heavy:
                return TrafficColor.heavyTraffic
            default:
                return self.defaultETAColor
            }
        }()
        
        // Current Leg
        let arrivalTime = Date(timeIntervalSinceNow: currentLegETA)
        let arrivalTimeString = shortDateFormatter.string(from: arrivalTime).lowercased()
        let distanceRemainingString = descriptiveLabel(forDistance: distanceRemaining)
        var arrivalText = "\(arrivalTimeString) • \(distanceRemainingString)"
        
        if navViewController.isLegFinalDestination == false, let destination = currentDestination {
            arrivalText += " • \(destination.displayTitle)"
        }
        
        bottomBarSecondaryLabel.text = arrivalText

        // Next Leg
        assert(currentDestination != nil, "currentDestination is nil")
        guard navViewController.isLegFinalDestination == false, let currentDestination = currentDestination, let nextDestinationIndex = destinations.index(of: currentDestination)?.advanced(by: 1) else {
            bottomBarFinalLabel.text = ""
            return
        }
        let nextDestinationName = destinations[nextDestinationIndex].displayTitle
        let nextTime = Date(timeIntervalSinceNow: finalETA)
        let nextTimeString = shortDateFormatter.string(from: nextTime).lowercased()

        bottomBarFinalLabel.text = "\(nextTimeString) • \(nextDestinationName)"
    }
    
    /// Navigation View Controller Delegate call to display warnings
    func update(warnings: [String]?) {
        navWarnings.removeAll()
        if let warnings = warnings, warnings.isEmpty == false {
            navWarnings.append(contentsOf: warnings)
        }
        updateWarnings()
    }
    
    /// Navigation View Controller Delegate call for the current speed limit the user is driving on
    func update(speedLimit: CLLocationSpeed) {
        
        // Hide the speed limit if we don't have one
        guard speedLimit > 0.0 else {
            UIView.animate(withDuration: 0.3) {
                self.speedLimitView.alpha = 0.0
            }
            return
        }
        
        // Show the speed limit view if its hidden
        if speedLimitView.alpha < 0.5 {
            UIView.animate(withDuration: 0.3) {
                self.speedLimitView.alpha = 1.0
            }
        }
        
        let speedLimitString = "\(Int(speedLimit.milesPerHour))"
        if speedLimitSpeed.text != speedLimitString {
            
            // if the speed limit changed, we announce it
            UIView.animate(withDuration: 0.15, animations: {
                self.speedLimitView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }, completion: { _ in
                UIView.animate(withDuration: 0.15) {
                    self.speedLimitView.transform = CGAffineTransform(scaleX: 1, y: 1)
                }
            })
            
            speedLimitSpeed.text = speedLimitString
        }
    }
    
    /// Navigation View Controller Delegate call when we need to show the "Recenter" button to allow the user to go back to showing the standard Navigation UI
    func userFollowMode(didChangeTo followMode: NavUserFollowMode) {
        guard followMode == .following else {
            UIView.animate(withDuration: 0.75, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: [.allowUserInteraction, .curveEaseOut], animations: {
                self.recenterButton.transform = CGAffineTransform(scaleX: 1, y: 1)
            }, completion: nil)
            return
        }
        
        UIView.animate(withDuration: 0.4, animations: {
            self.recenterButton.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        }) { _ in
            self.recenterButton.transform = CGAffineTransform(scaleX: 0, y: 0)
        }
    }
    
    /// Navigation Controller has notified us that we have reached one of the non-final destinations of a multi-stop route
    /// We will let the user either initiate the end of navigation or next destination
    func reachedDestination(_ destination:Destination,  nextDestination: Destination?, confirmArrival: @escaping MQConfirmArrivalBlock) {
        guard navViewController.state == .navigating else { return }
        
        var actions = [UIAlertAction]()
        
        if let nextDestination = nextDestination {
            let continueAction = UIAlertAction(title: "Reached Destination", style: .default, handler: { (action) in
                confirmArrival(true)
                self.navViewController.pauseNavigation()

                self.navHatManeuverLabel.text = "Arrived: \(destination.displayTitle)"
                self.bottomBarMainLabel.text = "➢ \(nextDestination.displayTitle)"
                self.bottomBarSecondaryLabel.text = "Tap to start navigation"

            })
            actions.append(continueAction)
            
            let endNavigationAction = UIAlertAction(title: "End Navigation", style: .destructive, handler: { (action) in
                confirmArrival(true)
            })
            actions.append(endNavigationAction)
        } else {
            let endNavigationAction = UIAlertAction(title: "Reached Destination", style: .default, handler: { (action) in
                confirmArrival(true)
            })
            actions.append(endNavigationAction)
        }
        
        let missedDestination = UIAlertAction(title: "Missed Destination", style: .default, handler: { (action) in
            confirmArrival(false)
        })
        actions.append(missedDestination)

        let alert = UIAlertController(title: destination.displayTitle, message: destination.displaySubtitle, preferredStyle: .actionSheet, actions: actions)
        
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(x: 0, y: view.bounds.height-1, width: view.bounds.width, height: 1)
        present(alert, animated: true, completion: nil)
    }
    
    /// When we update our routes, we want to bring up the route selection buttons
    func update(routes: [MQRoute]) {
        guard navViewController.state == .stopped, let drawer = self.parent as? PulleyViewController, let searchController = drawer.drawerContentViewController as? SearchDestinationViewController else { return }
        
        searchController.setup(routes: routes)
        drawer.setDrawerPosition(position: .partiallyRevealed, animated: true)
    }
}

// MARK: - TripPlanningProtocol

/// This extension allows the root view controller to update the NavViewController from the Search Dock
extension RootViewController: TripPlanningProtocol {
    var tripOptions: MQRouteOptions {
        get {
            return navViewController.tripOptions
        }
        
        set {
            navViewController.tripOptions = tripOptions
        }
    }
    var shouldReroute:Bool {
        get {
            return navViewController.shouldReroute
        }
        
        set {
            navViewController.shouldReroute = newValue
        }
    }
    
    var destinations: [Destination] {
        return navViewController.destinations
    }
    
    func refreshDestinations() {
        navViewController.refreshDestinations()
    }
    
    func showAttribution() {
        navViewController.showAttribution()
    }
    
    func consentChanged() {
        navViewController.userLocationTrackingConsentStatus = MQDemoOptions.shared.userLocationTrackingConsentStatus
    }
    
    func startNavigation(withRoute route: MQRoute) {
        navViewController.startNavigation(withRoute: route)
    }
    
    func clearNavigation() {
        navViewController.clearNavigation()
    }
    
    func selectedNew(destination: Destination) {
        navViewController.selectedNew(destination: destination)
    }
    func replace(destinations: [Destination]) {
        navViewController.replace(destinations: destinations)
    }
    
}





