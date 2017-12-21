// Copyright © 2017 Mapquest. All rights reserved.

import UIKit

class InstructionsTableViewCell: UITableViewCell {

    //MARK: Interface Builder Outlets
    @IBOutlet var hairlineView: UIView!
    @IBOutlet var distanceLabel: UILabel!
    @IBOutlet var requiredViewsView: UIView!
    @IBOutlet var emblemImageView: UIImageView!
    @IBOutlet var badgeImageView: UIImageView!
    @IBOutlet var iconLabel: UILabel!
    @IBOutlet var exitLabel: UILabel!
    @IBOutlet var promptLabel: KerningLabel!
    @IBOutlet var subtextLabel: KerningLabel!

    @IBOutlet var iconLabelCenterY: NSLayoutConstraint!
    @IBOutlet var promptLabelHeight: NSLayoutConstraint!
    @IBOutlet var subtextHeight: NSLayoutConstraint!
    @IBOutlet var promptCenterY: NSLayoutConstraint!
    @IBOutlet var subtextTop: NSLayoutConstraint!
    @IBOutlet var subtextBottom: NSLayoutConstraint!
    @IBOutlet var requiredTop: NSLayoutConstraint!
    
    //MARK: Public Properties
    var instruction: MQInstruction? = nil
    var isLastCell: Bool = false

    //MARK: - Public Methods
    func setUpCell() {
        guard let instruction = instruction else { return }
        promptLabel.text = instruction.instruction

        let promptHeight = InstructionsTableViewCell.heightForString(instruction.instruction, cellWidth: promptLabel.bounds.width)
        promptLabelHeight.constant = promptHeight

        distanceLabel.text = descriptiveLabel(forDistance: instruction.distanceToManeuver)
        emblemImageView.image = MQManeuver.image(maneuverType: instruction.maneuverType)
        badgeImageView.image = nil

        subtextTop.constant = 0

        if promptHeight < 20 && badgeImageView.image != nil {
            subtextBottom.constant = 17
            requiredTop.constant = 10
        } else {
            requiredTop.constant = 0
            subtextBottom.constant = 7
        }

        subtextHeight.constant = 0
        subtextLabel.text = ""

        iconLabel.text = ""

        iconLabelCenterY.constant = 0
        exitLabel.isHidden = true

        if isLastCell {
            hairlineView.isHidden = true
            distanceLabel.isHidden = true
        } else {
            distanceLabel.isHidden = false
            hairlineView.isHidden = false
        }

        layoutIfNeeded()
    }

    class func heightForString(_ string: String, cellWidth: CGFloat) -> CGFloat {
        return self.heightForString(string, font: UIFont(name: "Raleway", size: 16)!, width: cellWidth - 105)
    }

    //MARK: Private Methods
    private class func heightForString(_ string: String, font:UIFont, width:CGFloat) -> CGFloat {
        let attributedText = NSMutableAttributedString(string: string, attributes: [NSAttributedStringKey.font: font])
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        
        attributedText.addAttribute(NSAttributedStringKey.paragraphStyle, value: style, range: NSMakeRange(0, string.count))
        let rect = attributedText.boundingRect(with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), options: NSStringDrawingOptions.usesLineFragmentOrigin, context: nil)
        return rect.size.height;
    }
}
