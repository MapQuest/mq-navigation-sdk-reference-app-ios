//
//  InstructionsPageController.swift
//  MQNavigationDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import UIKit

class InstructionsPageController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    
    // MARK: Public Properties
    var pages = [UIViewController]()
    var selectedPageIndex = 0
    
    // MARK: - Internal Controller
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Only show the page view controller UI if we have more than one page
        if pages.count > 1 {
            dataSource = self
            delegate = self
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let firstPageToDisplay = pages[selectedPageIndex]
        setViewControllers([firstPageToDisplay], direction: .forward, animated: false, completion: nil)
        updateAddressTitle(with: firstPageToDisplay)
    }
    
    // MARK: - Page View Data Source
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = pages.index(of: viewController) else {
            return nil
        }
        
        let previousIndex = viewControllerIndex - 1
        
        // User is on the first view controller and swiped left
        guard previousIndex >= 0 else {
            return nil
        }

        return pages[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = pages.index(of: viewController) else {
            return nil
        }
        
        let nextIndex = viewControllerIndex + 1
        
        // User is on the last view controller and swiped right
        guard nextIndex < pages.count else {
            return nil
        }
        
        return pages[nextIndex]
    }
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return pages.count
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return selectedPageIndex
    }
    
    // MARK: Page View Delegate
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        guard let vc = pendingViewControllers.first, let viewControllerIndex = pages.index(of: vc) else { return }
        selectedPageIndex = viewControllerIndex
        updateAddressTitle(with: vc)
    }
    
    private func updateAddressTitle(with viewController: UIViewController) {
        guard let vc = viewController as? InstructionsViewController else { return }
        navigationItem.title = vc.displayAddress
    }
}
