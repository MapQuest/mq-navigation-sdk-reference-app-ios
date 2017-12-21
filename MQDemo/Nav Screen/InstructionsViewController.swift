//
//  InstructionsViewController.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import UIKit
import MQNavigation

protocol InstructionsViewControllerDelegate : NSObjectProtocol {
    func dismissInstructionsView()
}

//MARK: -
class InstructionsViewController: UIViewController {

    //MARK: Public Properties
    var currentRouteLeg : MQRouteLeg?
    var route: MQRoute?
    weak var delegate : InstructionsViewControllerDelegate?
    var flagString: String?
    var displayAddress : String? {
        didSet {
            guard let addressLabel = addressLabel else { return }
            addressLabel.text = displayAddress
        }
    }
    
    //MARK: Interface Builder Outlets
    @IBOutlet weak var tableView : UITableView!
    @IBOutlet weak var addressLabel : UILabel!
    @IBOutlet weak var dismissView : UIVisualEffectView!
    @IBOutlet weak var topBarView : UIVisualEffectView!
    @IBOutlet weak var flagTopSpace : NSLayoutConstraint!
    @IBOutlet weak var flag : UILabel!

    //MARK: Private Properties
    private let destinationCellIdentifier = "InstructionsTableViewCell"
    
    //MARK: - Internal Controller
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.indicatorStyle = .black
        
        let topInset: CGFloat = topBarView.frame.height //- tableView.frame.minY
        let bottomInset = dismissView.frame.height
        tableView.scrollIndicatorInsets = UIEdgeInsetsMake(topInset, 0, bottomInset, -2)
        tableView.contentInset = UIEdgeInsetsMake(topInset, 0, bottomInset, 0)
        
        if let flagString = flagString {
            flag.isHidden = false
            flag.text = flagString
            flagTopSpace.constant = 0
            let flagHeight = flag.frame.height
            tableView.scrollIndicatorInsets = UIEdgeInsetsMake(topInset + flagHeight, 0, bottomInset, -2)
            tableView.contentInset = UIEdgeInsetsMake(topInset + flagHeight, 0, bottomInset, 0)
        } else {
            flag.isHidden = true
            flagTopSpace.constant = -self.flag.frame.height
        }
        
        addressLabel.text = displayAddress
    }
    
    @IBAction func dismissViewController(_ sender: UIButton) {
        if let delegate = delegate {
            delegate.dismissInstructionsView()
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
}

//MARK: - UITableViewDataSource
extension InstructionsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let instructions = currentRouteLeg?.instructions else { return 0 }
        return instructions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: destinationCellIdentifier, for: indexPath) as! InstructionsTableViewCell
        
        if let instructions = currentRouteLeg?.instructions {
            cell.isLastCell = (indexPath.row == instructions.count - 1)
            cell.instruction = instructions[indexPath.row]
        } else {
            cell.instruction = nil
            cell.isLastCell = false
        }
        cell.setUpCell()
        return cell;
    }
}

//MARK: - UITableViewDelegate
extension InstructionsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 0
        guard let instruction = currentRouteLeg?.instructions[indexPath.row] else {
            return 50
        }
        height = 50
        let promptLabelHeight = InstructionsTableViewCell.heightForString(instruction.instruction, cellWidth: view.frame.width)
        let subtextLabelHeight: CGFloat = 0
        let textHeight = promptLabelHeight + subtextLabelHeight
        if promptLabelHeight < 20 && MQManeuver.hasImage(maneuverType: instruction.maneuverType) {
            height += 20
        }
        height += textHeight
        return height
    }
}
