//
//  SearchDestinationViewController.swift
//  MQDemo
//
//  Copyright © 2017 MapQuest. All rights reserved.
//

import UIKit
import Pulley

/// Panel that gives the user the ability to pick a destination
/// We use the MQSearchAhead framework to provide the results

class SearchDestinationViewController: UIViewController, SearchParentProtocol {
    
    //MARK: Interface Builder Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var gripperView: UIView!
    @IBOutlet weak var startNavigationStack: UIStackView!
    @IBOutlet weak var cancelNavigationButton: UIButton!
    @IBOutlet weak var searchParentView: UIView!
    
    // We adjust our 'header' based on the bottom safe area using this constraint
    @IBOutlet weak var headerSectionHeightConstraint: NSLayoutConstraint!
    
    //MARK: Public Propertyies
    var displayableDestinations = [Destination]()
    var shouldDisplayFavorites : Bool {
        guard let drawer = self.parent as? PulleyViewController else { return false }
        return drawer.drawerPosition == .open
    }
    
    //MARK: Private Properties
    private lazy var searchController = SearchController(parent: self)
    private var routes: [MQRoute]?
    
    fileprivate var drawerBottomSafeArea: CGFloat = 0.0 {
        didSet {
            self.loadViewIfNeeded()
            
            // We'll configure our UI to respect the safe area. In our small demo app, we just want to adjust the contentInset for the tableview.
            tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: drawerBottomSafeArea, right: 0.0)
        }
    }
    
    //MARK: - Internal Controller
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        gripperView.layer.cornerRadius = 2.5
        registerForKeyboardNotifications()
    }
    
    //MARK: Public Methods
    /// Start the navigation button
    @objc func startNavigation(_ button: UIButton) {
        
        guard let drawer = self.parent as? PulleyViewController,
            let routes = routes, routes.count > button.tag,
            let parent = drawer.primaryContentViewController as? DestinationManagementProtocol else { return }
        
        //don't allow the button to be double pressed
        button.isEnabled = false
        
        drawer.setDrawerPosition(position: .closed, animated: true)
        parent.startNavigation(withRoute: routes[button.tag])
    }
    
    @IBAction func cancelNavigation() {
        guard let drawer = self.parent as? PulleyViewController,
            let parent = drawer.primaryContentViewController as? DestinationManagementProtocol else { return }
        
        drawer.setDrawerPosition(position: .collapsed, animated: true)
        parent.clearNavigation()
    }
    
    func updateStartNavigationButtons(display: Bool) {
        searchParentView.isHidden = display
        tableView.isHidden = display
        startNavigationStack.isHidden = !display
        cancelNavigationButton.isHidden = startNavigationStack.isHidden
    }
    
    func setup(routes: [MQRoute]) {
        self.routes = routes
        let showNavigation = routes.count > 0
    
        updateStartNavigationButtons(display: showNavigation)
        
        //create the navigation stack button
        if showNavigation {
            startNavigationStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            func buttonFor(route: MQRoute, atIndex index: Int) -> UIButton? {
                guard let leg = route.legs.last, let eta = leg.traffic.estimatedTimeOfArrival.time?.timeIntervalSinceNow else { return nil }
                let name = (route.name.count > 0) ? route.name : "Start Navigation"
                
                let title = NSMutableAttributedString(string: "\(name)\n", attributes: [NSAttributedStringKey.foregroundColor:UIColor.blue, NSAttributedStringKey.font: UIFont.systemFont(ofSize: 12)])
                
                let etaString = "Arrival: \(timeFormatter.string(from: Date(timeIntervalSinceNow: eta)))"
                title.append(NSAttributedString(string: etaString, attributes: [NSAttributedStringKey.foregroundColor:UIColor.blue, NSAttributedStringKey.font: UIFont.systemFont(ofSize: 14)]))
                
                let style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                style.alignment = .center
                style.lineBreakMode = .byWordWrapping
                title.addAttribute(NSAttributedStringKey.paragraphStyle, value: style, range: NSMakeRange(0, title.length))
                
                let button = UIButton(type: .custom)
                button.titleLabel?.numberOfLines = 0
                button.titleLabel?.lineBreakMode = .byWordWrapping
                button.setAttributedTitle(title, for: .normal)
                button.addTarget(self, action: #selector(startNavigation(_:)), for: .touchUpInside)
                
                button.layer.borderColor = UIColor.lightGray.cgColor
                button.layer.borderWidth = 1.0
                button.tag = index
                
                return button
            }
            
            var index = 0
            routes.forEach {
                if let button = buttonFor(route: $0, atIndex: index) {
                    startNavigationStack.addArrangedSubview(button)
                }
                index += 1
            }
        }
    }
}

//MARK: - PulleyDrawerViewControllerDelegate
extension SearchDestinationViewController: PulleyDrawerViewControllerDelegate {
    
    func collapsedDrawerHeight(bottomSafeArea: CGFloat) -> CGFloat
    {
        // For devices with a bottom safe area, we want to make our drawer taller. Your implementation may not want to do that. In that case, disregard the bottomSafeArea value.
        return 68.0 + bottomSafeArea
    }
    
    func partialRevealDrawerHeight(bottomSafeArea: CGFloat) -> CGFloat
    {
        // For devices with a bottom safe area, we want to make our drawer taller. Your implementation may not want to do that. In that case, disregard the bottomSafeArea value.
        return 120 + bottomSafeArea
    }
    
    func supportedDrawerPositions() -> [PulleyPosition] {
        return PulleyPosition.all // You can specify the drawer positions you support. This is the same as: [.open, .partiallyRevealed, .collapsed, .closed]
    }
    
    // This function is called by Pulley anytime the size, drawer position, etc. changes. It's best to customize your VC UI based on the bottomSafeArea here (if needed).
    func drawerPositionDidChange(drawer: PulleyViewController, bottomSafeArea: CGFloat)
    {
        if drawer.drawerPosition != .partiallyRevealed {
            updateStartNavigationButtons(display: false)
        }
        
        // We want to know about the safe area to customize our UI. Our UI customization logic is in the didSet for this variable.
        drawerBottomSafeArea = bottomSafeArea
        
        /*
         Some explanation for what is happening here:
         1. Our drawer UI needs some customization to look 'correct' on devices like the iPhone X, with a bottom safe area inset.
         2. We only need this when it's in the 'collapsed' position, so we'll add some safe area when it's collapsed and remove it when it's not.
         3. These changes are captured in an animation block (when necessary) by Pulley, so these changes will be animated along-side the drawer automatically.
         */
        if drawer.drawerPosition == .collapsed {
            headerSectionHeightConstraint.constant = 68.0 + drawerBottomSafeArea
            
            if let drawer = self.parent as? PulleyViewController {
                guard let parent = drawer.primaryContentViewController as? DestinationManagementProtocol else {
                    return
                }
                
                parent.clearNavigation()
                searchBar.text = ""
                clearSearchResults()
                searchBar.showsCancelButton = false
            }
        } else {
            clearSearchResults()
            headerSectionHeightConstraint.constant = 68.0
        }
        
        // Handle tableview scrolling / searchbar editing
        
        tableView.isScrollEnabled = drawer.drawerPosition == .open
        
        if drawer.drawerPosition != .open {
            searchBar.resignFirstResponder()
        }
    }
}

//MARK: - UISearchBarDelegate
extension SearchDestinationViewController: UISearchBarDelegate {
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
        if let drawerVC = self.parent as? PulleyViewController {
            drawerVC.setDrawerPosition(position: .open, animated: true)
        }
        
        searchBar.showsCancelButton = true
        searchBar.text = ""
        self.clearSearchResults()
        
        //no location
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchController.search(searchText)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchController.cancel()
        OperationQueue.main.addOperation { [weak self] in
            
            guard let strongSelf = self else { return }
            
            strongSelf.clearSearchResults()
            if let drawerVC = strongSelf.parent as? PulleyViewController {
                drawerVC.setDrawerPosition(position: .collapsed, animated: true)
            }
        }
    }
}

//MARK: - UITableViewDataSource
extension SearchDestinationViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numberOfRowsIn(section: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cellForRowAt(indexPath: indexPath)
    }
}

//MARK: - UITableViewDelegate
extension SearchDestinationViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70.0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let drawer = self.parent as? PulleyViewController {
            
            guard let parent = drawer.primaryContentViewController as? DestinationManagementProtocol else {
                assertionFailure("Parent View Controller for Pulley doesn't support TripUpdating")
                return
            }
            
            let destination = displayableDestinations[indexPath.row]
            MQDemoOptions.shared.addMRU(destination: destination)

            parent.selectedNew(destination: destination)
            parent.refreshDestinations()
            
            drawer.setDrawerPosition(position: .partiallyRevealed, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return trailingSwipeActionsConfigurationForRowAt(indexPath: indexPath)
    }
}

//MARK: - Keyboard handling
extension SearchDestinationViewController {
    
    private func registerForKeyboardNotifications() {
        let center = NotificationCenter.default
        
        center.addObserver(forName: NSNotification.Name.UIKeyboardDidShow, object: nil, queue: nil) { notification in
            guard let userInfo = notification.userInfo, let keyboardSizeKey = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue, let tableView = self.tableView else { return }
            let keyboardSize = keyboardSizeKey.cgRectValue.size
            let contentInsets = UIEdgeInsetsMake(tableView.contentInset.top, tableView.contentInset.left, keyboardSize.height, tableView.contentInset.right)
            tableView.contentInset = contentInsets
            tableView.scrollIndicatorInsets = contentInsets
        }
        
        center.addObserver(forName: NSNotification.Name.UIKeyboardWillHide, object: nil, queue: nil) { notification in
            guard let tableView = self.tableView else { return }
            let contentInsets = UIEdgeInsetsMake(tableView.contentInset.top, tableView.contentInset.left, 0, tableView.contentInset.right)
            tableView.contentInset = contentInsets
            tableView.scrollIndicatorInsets = contentInsets
        }
    }

}
