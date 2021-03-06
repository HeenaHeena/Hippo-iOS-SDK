//
//  ChatInfoAgentTableViewCell.swift
//  Fugu
//
//  Created by clickpass on 10/11/17.
//  Copyright © 2017 Socomo Technologies Private Limited. All rights reserved.
//

import UIKit

class ChatInfoAgentTableViewCell: UITableViewCell {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var agentProfileImage: UIImageView!
    @IBOutlet weak var agentNameLabel: UILabel!
    @IBOutlet weak var namePlaceHolderImage: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        resetData()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setUpData(agentId: Int, agentName: String) -> ChatInfoAgentTableViewCell {
//        resetData()
    
        agentNameLabel.text = agentName.isEmpty ? "Unassigned" : agentName
        containerView.layer.borderColor = UIColor.paleGrey.cgColor
        
        return self
    }
    
    func resetData() {
        selectionStyle = .none
        agentProfileImage.image = UIImage()
        agentNameLabel.text = ""
    }
}
