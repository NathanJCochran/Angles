//
//  VideoTableViewCell.swift
//  Angles
//
//  Created by Nathaniel J Cochran on 4/24/16.
//  Copyright © 2016 Nathaniel J Cochran. All rights reserved.
//

import UIKit

class VideoTableViewCell: UITableViewCell {
    
    // MARK: Properties
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var thumbnailImage: UIImageView!
    @IBOutlet weak var nameTextField: UITextField!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
