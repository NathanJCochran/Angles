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

class FramesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    // MARK: Properties
    
    var video: Video!
    var videoAsset: AVURLAsset!
    var videoImageGenerator: AVAssetImageGenerator!
    var currentFrame: Frame!
    var pointUIViews = [UIView]()
    
    // MARK: Outlets
    
    @IBOutlet weak var frameImageView: UIImageView!
    @IBOutlet weak var frameSlider: UISlider!
    @IBOutlet weak var videoDurationLabel: UILabel!
    @IBOutlet weak var frameCollectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Make sure video was properly set:
        if video == nil {
            displayErrorAlert("Video field not properly set")
            return
        }
        
        // Load video and image generator:
        videoAsset = AVURLAsset(URL: video.videoURL, options: nil)
        videoImageGenerator = AVAssetImageGenerator(asset: videoAsset)
        videoImageGenerator.appliesPreferredTrackTransform = true
        videoImageGenerator.requestedTimeToleranceBefore = kCMTimeZero
        videoImageGenerator.requestedTimeToleranceAfter = kCMTimeZero
        
        // Set slider min and max:
        frameSlider.minimumValue = 0
        frameSlider.maximumValue = Float(videoAsset.duration.seconds)
        
        if video.frames.count > 0 {
            setCurrentFrameTo(video.frames.first!)
        } else {
            // Default
            setFrameImage(0)
            frameSlider.value = 0
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("Received memory warning")
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        clearPointsFromScreen()
        coordinator.animateAlongsideTransition(nil, completion: {
            _ in
            self.drawCurrentPoints()
        })
    }
    
    // MARK: Actions
    
    @IBAction func sliderMoved(sender: UISlider) {
        clearPointsFromScreen()
        let seconds = Double(sender.value)
        setFrameImage(seconds)
        for frame in video.frames {
            if frame.seconds == seconds {
                setCurrentFrameTo(frame)
                break
            }
        }
    }
    
    @IBAction func selectPoint(sender: UITapGestureRecognizer) {
        let location = sender.locationInView(frameImageView)
        let frameImageRect = getFrameImageRect()
        
        if frameImageRect.contains(location) {
            drawPointAt(location)
            currentFrame.points.append(normalizePoint(location))
        }
    }
    
    @IBAction func saveFrame(sender: UIBarButtonItem) {
        video.frames.append(currentFrame)
        let newIndexPath = NSIndexPath(forRow: video.frames.count-1, inSection: 0)
        frameCollectionView.insertItemsAtIndexPaths([newIndexPath])
    }
    
    // MARK: UICollectionViewDataSource
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return video.frames.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cellIdentifier = "FrameCollectionViewCell"
        let cell = frameCollectionView.dequeueReusableCellWithReuseIdentifier(cellIdentifier, forIndexPath: indexPath) as! FrameCollectionViewCell
        cell.frameImageView.image = video.frames[indexPath.item].image
        return cell
    }
    
    // MARK: UICollectionViewDelegate
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        // TODO: HIGHLIGHTING
        let frame = video.frames[indexPath.item]
        setCurrentFrameTo(frame)
    }
    
    // MARK: Helper methods
    
    func setCurrentFrameTo(frame: Frame) {
        clearPointsFromScreen()
        setFrameImage(frame.seconds)
        setSlider(frame.seconds)
        currentFrame = frame
        drawCurrentPoints()
    }
    
    func setFrameImage(seconds: Double) {
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
    
    func setSlider(seconds: Double) {
        frameSlider.setValue(Float(seconds), animated: true)
    }
    
    func drawCurrentPoints() {
        for point in currentFrame.points {
            self.drawNormalizedPointAt(point)
        }
    }

    func drawNormalizedPointAt(point: CGPoint) {
        drawPointAt(denormalizePoint(point))
    }
    
    func drawPointAt(point: CGPoint) {
        let pointDiameter = getFrameImageRect().size.width / 20
        let circle = UIView(frame: CGRect(
            x: point.x - (pointDiameter / 2),
            y: point.y - (pointDiameter / 2),
            width: pointDiameter,
            height: pointDiameter
            )
        )
        circle.layer.cornerRadius = pointDiameter / 2
        circle.backgroundColor = UIColor.blueColor()
        circle.alpha = 0.5
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

