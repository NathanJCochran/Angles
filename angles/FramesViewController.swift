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
    
    // MARL: Constants
    
    let pointDiameter = CGFloat(25)
    
    // MARK: Properties
    
    var video: Video?
    var videoAsset: AVURLAsset!
    var videoImageGenerator: AVAssetImageGenerator!
    var currentFrame: Frame!
    var pointUIViews = [UIView]()
    
    // MARK: Outlets
    
    @IBOutlet weak var frameImageView: UIImageView!
    @IBOutlet weak var frameSlider: UISlider!
    @IBOutlet weak var videoDurationLabel: UILabel!

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
        videoImageGenerator.requestedTimeToleranceBefore = kCMTimeZero
        videoImageGenerator.requestedTimeToleranceAfter = kCMTimeZero
        
        // Set slider min and max:
        frameSlider.minimumValue = 0
        frameSlider.maximumValue = Float(videoAsset.duration.seconds)
        frameSlider.value = 0
        
        // Set initial thumbnail:
        setFrameAtSeconds(0)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("Received memory warning")
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animateAlongsideTransition(nil, completion: {
            _ in
            self.clearPointsFromScreen()
            for point in self.currentFrame.points {
                self.drawNormalizedPointAt(point)
            }
        })
    }
    
    // MARK: Actions
    
    @IBAction func sliderMoved(sender: UISlider) {
        clearPointsFromScreen()
        let seconds = Double(sender.value)
        setFrameAtSeconds(seconds)
    }
    
    @IBAction func selectPoint(sender: UITapGestureRecognizer) {
        let location = sender.locationInView(frameImageView)
        let frameImageRect = getFrameImageRect()
        
        if frameImageRect.contains(location) {
            drawPointAt(location)
            currentFrame.points.append(normalizePoint(location))
        }
    }
    
    // MARK: Helper methods
    
    func setFrameAtSeconds(seconds: Double) {
        do {
            setVideoTimeLabel(seconds)
            let time = CMTime(seconds:seconds, preferredTimescale: videoAsset.duration.timescale)
            let thumbnailImage = try videoImageGenerator.copyCGImageAtTime(time, actualTime: nil)
            currentFrame = Frame(seconds: seconds, image: UIImage(CGImage: thumbnailImage))
            frameImageView.image = currentFrame.image
        } catch let error as NSError {
            displayErrorAlert("Could not generate thumbail image from video at " + String(seconds) + " seconds")
            print(error)
        }
    }
    
    func setVideoTimeLabel(totalSeconds:Double) {
        let hours = Int(floor(totalSeconds / 3600))
        let minutes = Int(floor(totalSeconds % 3600 / 60))
        let seconds = Int(floor(totalSeconds % 3600 % 60))
        videoDurationLabel.text = String(format:"%d:%02d:%02d", hours, minutes, seconds)
    }

    func drawNormalizedPointAt(point: CGPoint) {
        drawPointAt(denormalizePoint(point))
    }
    
    func drawPointAt(point: CGPoint) {
        let circle = UIView(frame: CGRect(
            x: point.x - (pointDiameter / 2),
            y: point.y - (pointDiameter / 2),
            width: pointDiameter,
            height: pointDiameter
            )
        )
        circle.layer.cornerRadius = pointDiameter / 2
        circle.backgroundColor = UIColor.orangeColor()
        self.frameImageView.addSubview(circle)
        self.pointUIViews.append(circle)
    }
    
    func clearPointsFromScreen() {
        for pointUIView in self.pointUIViews {
            pointUIView.removeFromSuperview()
        }
        self.pointUIViews.removeAll()
    }
    
    func normalizePoint(point: CGPoint) -> CGPoint {
        let frameImageRect = getFrameImageRect()
        let adjustedPoint = CGPoint(x: point.x - frameImageRect.minX, y: point.y - frameImageRect.minY)
        let scaledPoint = CGPoint(
            x: (adjustedPoint.x / frameImageRect.width) * frameImageView.image!.size.width,
            y: (adjustedPoint.y / frameImageRect.height) * frameImageView.image!.size.height
        )
        return scaledPoint
    }
    
    func denormalizePoint(point:CGPoint) -> CGPoint{
        let frameImageRect = getFrameImageRect()
        let adjustedPoint = CGPoint(
            x: (point.x / frameImageView.image!.size.width) * frameImageRect.width,
            y: (point.y / frameImageView.image!.size.height) * frameImageRect.height
        )
        let realPoint = CGPoint(x: adjustedPoint.x + frameImageRect.minX, y: adjustedPoint.y + frameImageRect.minY)
        return realPoint
    }
    
    func getFrameImageRect() -> CGRect {
        let widthRatio = frameImageView.bounds.size.width / frameImageView.image!.size.width
        let heightRatio = frameImageView.bounds.size.height / frameImageView.image!.size.height
        let scale = min(widthRatio, heightRatio)
        let imageWidth = scale * frameImageView.image!.size.width
        let imageHeight = scale * frameImageView.image!.size.height
        let x = (frameImageView.bounds.size.width - imageWidth) / 2
        let y = (frameImageView.bounds.size.height - imageHeight) / 2
        return CGRect(x: x, y: y, width: imageWidth, height: imageHeight)
    }
    
    func displayErrorAlert(message: String) {
        print(message)
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
    }
}

