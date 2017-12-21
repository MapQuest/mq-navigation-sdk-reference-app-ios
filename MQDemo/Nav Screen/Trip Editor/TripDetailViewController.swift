//
//  TripDetailViewController.swift
//  MQDemo
//
//  Copyright © 2017 MapQuest. All rights reserved.
//

import UIKit
import MQNavigation

/// Sets multiple destinations and route options
class TripDetailViewController: UITableViewController {

    // MARK: Public Properties
    var destinations = [Destination]()
    weak var delegate: TripPlanningProtocol? {
        didSet {
            guard let delegate = delegate else { return }
            self.destinations = delegate.destinations

            guard isViewLoaded else { return }
            self.tableView.reloadData()
        }
    }

    // MARK: Interface Builder Outlets
    @IBOutlet weak var driveTypeSegment: UISegmentedControl!
    @IBOutlet weak var avoidTolls: UISwitch!
    @IBOutlet weak var avoidHighways: UISwitch!
    @IBOutlet weak var allowInformationSharing: UISwitch!

    // MARK: Private Properties
    private let destinationCellIdentifier = "destination"

    override func viewDidLoad() {
        super.viewDidLoad()

        isEditing = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()

        // will add this when we support walking
//        driveTypeSegment.selectedSegmentIndex = delegate?.tripOptions.

        avoidTolls.isOn = delegate?.tripOptions.tolls != MQRouteOptionType.allow
        avoidHighways.isOn = delegate?.tripOptions.highways != MQRouteOptionType.allow
        allowInformationSharing.isOn = MQDemoOptions.shared.userConsentedTracking
    }

    // MARK: - Public Methods
    func refreshDestinations() {
        tableView.reloadData()
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return destinations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: destinationCellIdentifier, for: indexPath)
        cell.textLabel?.text = destinations[indexPath.row].displayTitle
        cell.detailTextLabel?.text = destinations[indexPath.row].displaySubtitle
        return cell
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            destinations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        let destination = destinations[fromIndexPath.row]
        destinations.remove(at: fromIndexPath.row)
        destinations.insert(destination, at: to.row)
    }

    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        guard destinations.count > 1 else { return false }
        return true
    }

    // MARK: Actions
    @IBAction func attributionsTouched(_ sender: Any) {
        delegate?.showAttribution()
    }
    @IBAction func tollSwitch(_ sender: UISwitch) {
        delegate?.tripOptions.tolls = sender.isOn ? .avoid : .allow
    }
    @IBAction func highwaySwitch(_ sender: UISwitch) {
        delegate?.tripOptions.highways = sender.isOn ? .avoid : .allow
    }
    @IBAction func driveTypeAction(_ sender: UISegmentedControl) {
    }
    @IBAction func consentAction(_ sender: UISwitch) {
        MQDemoOptions.shared.userConsentedTracking = sender.isOn
        delegate?.consentChanged()
    }
}

// MARK: DestinationSearchSelectionProtocol
extension TripDetailViewController: DestinationSearchSelectionProtocol {
    func selectedNew(destination: Destination) {
        destinations.append(destination)
        tableView.reloadData()
    }
}
