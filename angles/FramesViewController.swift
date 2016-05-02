//
//  ViewController.swift
//  angles
//
//  Created by Nathan on 4/24/16.
//  Copyright © 2016 Nathan. All rights reserved.
//

import UIKit
import CoreMedia
import AVFoundation

class FramesViewController: UIViewController {
    
    // MARK: Properties
    var video: Video?
    var videoAsset: AVURLAsset!
    var videoImageGenerator: AVAssetImageGenerator!
    @IBOutlet weak var frameImageView: UIImageView!
    @IBOutlet weak var frameSlider: UISlider!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Make sure video was properly set:
        if video == nil {
            displayErrorAlert("Video field not properly set")
            return
        }
        
        // Load video and image generator:
        videoAsset = AVURLAsset(URL: video!.videoURL, options: nil)
        videoImageGenerator = AVAssetImageGenerator(asset: videoAsset)
        videoImageGenerator.appliesPreferredTrackTransform = true
        
        // Set slider min and max:
        frameSlider.minimumValue = 0
        frameSlider.maximumValue = Float(videoAsset.duration.seconds)
        frameSlider.value = 0
        
        print(video!.videoURL.absoluteString)
        
        // Set initial thumbnail:
        do {
            let thumbnailImage = try videoImageGenerator.copyCGImageAtTime(CMTime(seconds:0, preferredTimescale: 1), actualTime: nil)
            frameImageView.image = UIImage(CGImage: thumbnailImage)
            
        } catch let error as NSError {
            displayErrorAlert("Could not generate thumbail image from video")
            print(error)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("Received memory warning")
    }
    
    // MARK: Helper methods
    
    func displayErrorAlert(message: String) {
        print(message)
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
    }
    
    func setThumbnail() {
        
    }
}

