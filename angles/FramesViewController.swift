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
            frameCollectionView.selectItemAtIndexPath(NSIndexPath(forItem: 0, inSection: 0), animated: true, scrollPosition: .None)
        } else {
            // Default
            setCurrentFrameTo(0)
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
            self.drawNormalizedPoints(self.currentFrame.points)
        })
    }
    
    // MARK: Actions
    
    @IBAction func sliderMoved(sender: UISlider) {
        let seconds = Double(sender.value)
        setCurrentFrameTo(seconds)
    }
    
    @IBAction func selectPoint(sender: UITapGestureRecognizer) {
        let location = sender.locationInView(frameImageView)
        let frameImageRect = getFrameImageRect()
        
        if frameImageRect.contains(location) {
            drawPoint(location)
            currentFrame.points.append(normalizePoint(location))
        }
    }
    
    @IBAction func saveFrame(sender: UIBarButtonItem) {
        var idx = video.frames.count
        for (i, frame) in video.frames.enumerate() {
            if frame.seconds > currentFrame.seconds {
                idx = i
                break
            }
        }
        video.frames.insert(currentFrame, atIndex: idx)
        let newIndexPath = NSIndexPath(forItem: idx, inSection: 0)
        frameCollectionView.insertItemsAtIndexPaths([newIndexPath])
        frameCollectionView.selectItemAtIndexPath(newIndexPath, animated: true, scrollPosition: .CenteredHorizontally)
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
        let frame = video.frames[indexPath.item]
        setCurrentFrameTo(frame)
    }
    
    // MARK: Helper methods
    
    private func setCurrentFrameTo(frame: Frame) {
        clearPointsFromScreen()
        setVideoTimeLabel(frame.seconds)
        setSlider(frame.seconds)
        frameImageView.image = frame.image
        drawNormalizedPoints(frame.points)
        currentFrame = frame
    }
    
    private func setCurrentFrameTo(seconds: Double) {
        do {
            // Generate new frame image from video asset:
            let time = CMTime(seconds:seconds, preferredTimescale: videoAsset.duration.timescale)
            let cgImage = try videoImageGenerator.copyCGImageAtTime(time, actualTime: nil)
            let image = UIImage(CGImage: cgImage)
            
            clearPointsFromScreen()
            clearFrameSelection()
            setVideoTimeLabel(seconds)
            frameImageView.image = image
            currentFrame = Frame(seconds: seconds, image: image)
        } catch let error as NSError {
            displayErrorAlert("Could not generate thumbail image from video at " + String(seconds) + " seconds")
            print(error)
        }
    }
    
    private func setVideoTimeLabel(totalSeconds:Double) {
        let hours = Int(floor(totalSeconds / 3600))
        let minutes = Int(floor(totalSeconds % 3600 / 60))
        let seconds = Int(floor(totalSeconds % 3600 % 60))
        videoDurationLabel.text = String(format:"%d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func setSlider(seconds: Double) {
        frameSlider.setValue(Float(seconds), animated: true)
    }
    
    private func clearFrameSelection() {
        for indexPath in frameCollectionView.indexPathsForSelectedItems()! {
            frameCollectionView.deselectItemAtIndexPath(indexPath, animated: true)
        }
    }
    
    private func drawNormalizedPoints(points: [CGPoint]) {
        for point in points {
            drawNormalizedPoint(point)
        }
    }

    private func drawNormalizedPoint(point: CGPoint) {
        drawPoint(denormalizePoint(point))
    }
    
    private func drawPoint(point: CGPoint) {
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
        frameImageView.addSubview(circle)
        pointUIViews.append(circle)
    }
    
    private func clearPointsFromScreen() {
        for pointUIView in pointUIViews {
            pointUIView.removeFromSuperview()
        }
        pointUIViews.removeAll()
    }
    
    private func normalizePoint(point: CGPoint) -> CGPoint {
        let frameImageRect = getFrameImageRect()
        let adjustedPoint = CGPoint(x: point.x - frameImageRect.minX, y: point.y - frameImageRect.minY)
        let scaledPoint = CGPoint(
            x: (adjustedPoint.x / frameImageRect.width) * frameImageView.image!.size.width,
            y: (adjustedPoint.y / frameImageRect.height) * frameImageView.image!.size.height
        )
        return scaledPoint
    }
    
    private func denormalizePoint(point:CGPoint) -> CGPoint{
        let frameImageRect = getFrameImageRect()
        let adjustedPoint = CGPoint(
            x: (point.x / frameImageView.image!.size.width) * frameImageRect.width,
            y: (point.y / frameImageView.image!.size.height) * frameImageRect.height
        )
        let realPoint = CGPoint(x: adjustedPoint.x + frameImageRect.minX, y: adjustedPoint.y + frameImageRect.minY)
        return realPoint
    }
    
    private func getFrameImageRect() -> CGRect {
        let widthRatio = frameImageView.bounds.size.width / frameImageView.image!.size.width
        let heightRatio = frameImageView.bounds.size.height / frameImageView.image!.size.height
        let scale = min(widthRatio, heightRatio)
        let imageWidth = scale * frameImageView.image!.size.width
        let imageHeight = scale * frameImageView.image!.size.height
        let x = (frameImageView.bounds.size.width - imageWidth) / 2
        let y = (frameImageView.bounds.size.height - imageHeight) / 2
        return CGRect(x: x, y: y, width: imageWidth, height: imageHeight)
    }
    
    private func displayErrorAlert(message: String) {
        print(message)
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
    }
}

