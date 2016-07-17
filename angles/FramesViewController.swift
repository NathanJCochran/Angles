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

protocol SaveVideoDelegate {
    func saveVideos()
}

class FramesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    let font = "Helvetica"
    let fontSize = CGFloat(14.0)
    
    // MARK: Properties
    
    var video: Video!
    var currentFrame: Frame!
    var videoAsset: AVURLAsset!
    var videoImageGenerator: AVAssetImageGenerator!
    var documentController: UIDocumentInteractionController!
    
    // MARK: References to drawn images:
    var pointShapeLayers = [CAShapeLayer]()
    var lineShapeLayers = [CAShapeLayer]()
    var angleLabelTextLayers = [CATextLayer]()
    
    // MARK: Point colors:
    var pointColors = [UIColor.blueColor(), UIColor.orangeColor(), UIColor.greenColor(),
                       UIColor.yellowColor(), UIColor.redColor(), UIColor.cyanColor(),
                       UIColor.magentaColor(), UIColor.whiteColor()]
    
    // MARK: Frame button references for sake of toggle:
    var saveFrameButtonRef: UIBarButtonItem!
    var deleteFrameButtonRef: UIBarButtonItem!
    
    // MARK: Save videos delegate
    var saveDelegate: SaveVideoDelegate!
    
    // MARK: Outlets
    @IBOutlet weak var saveFrameButton: UIBarButtonItem!
    @IBOutlet weak var deleteFrameButton: UIBarButtonItem!
    @IBOutlet weak var exportButton: UIBarButtonItem!
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
        
        // Make sure save delegate was property set:
        if saveDelegate == nil {
            displayErrorAlert("Save delegate field not properly set")
        }
        
        // Save references to bar button items so we can toggle their existence:
        saveFrameButtonRef = saveFrameButton
        deleteFrameButtonRef = deleteFrameButton
        
        // Load video and image generator:
        videoAsset = AVURLAsset(URL: video.videoURL, options: nil)
        videoImageGenerator = AVAssetImageGenerator(asset: videoAsset)
        videoImageGenerator.appliesPreferredTrackTransform = true
        videoImageGenerator.requestedTimeToleranceBefore = kCMTimeZero
        videoImageGenerator.requestedTimeToleranceAfter = kCMTimeZero
        
        // Load document controller:
        documentController = UIDocumentInteractionController(URL: video.getCSVURL())
        
        // Set slider min and max:
        frameSlider.minimumValue = 0
        frameSlider.maximumValue = Float(videoAsset.duration.seconds)
        
        // Set current frame to first saved frame or default:
        if video.frames.count > 0 {
            setCurrentFrameTo(video.frames.first!, drawPoints: false)
            frameCollectionView.selectItemAtIndexPath(NSIndexPath(forItem: 0, inSection: 0), animated: true, scrollPosition: .None)
        } else {
            // Default
            setCurrentFrameTo(0)
            frameSlider.value = 0
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        clearPointsFromScreen()
        clearLinesFromScreen()
        clearAngleLabelsFromScreen()
        drawNormalizedPoints(currentFrame.points)
        drawLinesForNormalizedPoints(currentFrame.points)
        drawAngleLabelsForNormalizedPoints(currentFrame.points)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("Received memory warning")
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        clearPointsFromScreen()
        clearLinesFromScreen()
        clearAngleLabelsFromScreen()
        coordinator.animateAlongsideTransition(nil, completion: {
            _ in
            self.drawNormalizedPoints(self.currentFrame.points)
            self.drawLinesForNormalizedPoints(self.currentFrame.points)
            self.drawAngleLabelsForNormalizedPoints(self.currentFrame.points)
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
            if currentFrame.points.count > 0 {
                drawLine(denormalizePoint(currentFrame.points.last!), point2: location)
            }
            if currentFrame.points.count > 1 {
                let point1 = currentFrame.points[currentFrame.points.count - 2]
                let point2 = currentFrame.points[currentFrame.points.count - 1]
                drawAngleLabel(denormalizePoint(point1), point2: denormalizePoint(point2), point3: location)
            }
            currentFrame.points.append(normalizePoint(location))
            saveDelegate.saveVideos()
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
        showDeleteFrameButton()
        saveDelegate.saveVideos()
    }
    
    @IBAction func deleteFrame(sender: UIBarButtonItem) {
        let selectedItemPath = frameCollectionView.indexPathsForSelectedItems()!.first
        if selectedItemPath == nil {
            displayErrorAlert("Could not get index path of currently selected frame")
            return
        }
        video.frames.removeAtIndex(selectedItemPath!.item)
        frameCollectionView.deleteItemsAtIndexPaths([selectedItemPath!])
        currentFrame.points.removeAll()
        clearPointsFromScreen()
        clearLinesFromScreen()
        clearAngleLabelsFromScreen()
        showSaveFrameButton()
        saveDelegate.saveVideos()
    }
    
    @IBAction func export(sender: UIBarButtonItem) {
        do {
            try video.saveCSV()
            documentController.presentOptionsMenuFromBarButtonItem(exportButton, animated: true)
        } catch Video.VideoError.SaveError(let message, let error) {
            displayErrorAlert(message)
            if error != nil {
                print(error)
            }
        } catch let error as NSError {
            displayErrorAlert("Something went wrong while attempting to export the data to CSV format")
            print(error)
        }
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
    
    // MARK: Set UI Elements:
    
    private func setCurrentFrameTo(frame: Frame, drawPoints: Bool = true) {
        showDeleteFrameButton()
        clearPointsFromScreen()
        clearLinesFromScreen()
        clearAngleLabelsFromScreen()
        setVideoTimeLabel(frame.seconds)
        setSlider(frame.seconds)
        frameImageView.image = frame.image
        if drawPoints {
            drawNormalizedPoints(frame.points)
            drawLinesForNormalizedPoints(frame.points)
            drawAngleLabelsForNormalizedPoints(frame.points)
        }
        currentFrame = frame
    }
    
    private func setCurrentFrameTo(seconds: Double) {
        do {
            // Generate new frame image from video asset:
            let time = CMTime(seconds:seconds, preferredTimescale: videoAsset.duration.timescale)
            let cgImage = try videoImageGenerator.copyCGImageAtTime(time, actualTime: nil)
            let image = UIImage(CGImage: cgImage)
            
            showSaveFrameButton()
            clearPointsFromScreen()
            clearLinesFromScreen()
            clearAngleLabelsFromScreen()
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
    
    private func showSaveFrameButton() {
        if saveFrameButtonRef == nil {
            print("saveframebutton is nil")
        } else {
            navigationItem.setRightBarButtonItems([exportButton, saveFrameButtonRef], animated: true)
        }
    }
    
    private func showDeleteFrameButton() {
        if saveFrameButtonRef == nil {
            print("deleteframebutton is nil")
        } else {
            navigationItem.setRightBarButtonItems([exportButton, deleteFrameButtonRef], animated: true)
        }
    }
    
    // MARK: Draw Points
    
    private func drawNormalizedPoints(points: [CGPoint]) {
        for point in points {
            drawNormalizedPoint(point)
        }
    }

    private func drawNormalizedPoint(point: CGPoint) {
        drawPoint(denormalizePoint(point))
    }
    
    private func drawPoint(point: CGPoint) {
        let pointDiameter = getFrameImageRect().size.width / 25
        let rect = CGRect(
            x: point.x - (pointDiameter / 2),
            y: point.y - (pointDiameter / 2),
            width: pointDiameter,
            height: pointDiameter
        )
        let circlePath = UIBezierPath(ovalInRect: rect)
        
        let color = pointColors[pointShapeLayers.count%pointColors.count]
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = circlePath.CGPath
        shapeLayer.strokeColor = color.CGColor
        shapeLayer.fillColor = color.colorWithAlphaComponent(0.5).CGColor
        frameImageView.layer.addSublayer(shapeLayer)
        pointShapeLayers.append(shapeLayer)
    }
    
    private func clearPointsFromScreen() {
        for pointShapeLayer in pointShapeLayers {
            pointShapeLayer.removeFromSuperlayer()
        }
        pointShapeLayers.removeAll()
    }
    
    // MARK: Draw Lines
    
    private func drawLinesForNormalizedPoints(points: [CGPoint]) {
        if points.count > 1 {
            for i in 1..<points.count {
                drawLineForNormalizedPoints(points[i-1], point2: points[i])
            }
        }
    }
    
    private func drawLineForNormalizedPoints(point1: CGPoint, point2: CGPoint) {
        drawLine(denormalizePoint(point1), point2: denormalizePoint(point2))
    }

    
    private func drawLine(point1: CGPoint, point2: CGPoint) {
        let path = UIBezierPath()
        path.moveToPoint(point1)
        path.addLineToPoint(point2)
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.CGPath
        shapeLayer.strokeColor = UIColor.blueColor().CGColor
        frameImageView.layer.addSublayer(shapeLayer)
        lineShapeLayers.append(shapeLayer)
    }
    
    private func clearLinesFromScreen() {
        for lineShapeLayer in lineShapeLayers {
            lineShapeLayer.removeFromSuperlayer()
        }
        lineShapeLayers.removeAll()
    }
    
    // MARK: Draw Angle Labels:
    
    private func drawAngleLabelsForNormalizedPoints(points:[CGPoint]) {
        if points.count > 2 {
            for i in 0..<points.count-2 {
                drawAngleLabelForNormalizedPoints(points[i], point2: points[i+1], point3: points[i+2])
            }
        }
    }
    
    private func drawAngleLabelForNormalizedPoints(point1:CGPoint, point2:CGPoint, point3:CGPoint) {
        drawAngleLabel(denormalizePoint(point1), point2: denormalizePoint(point2), point3: denormalizePoint(point3))
    }
    
    private func drawAngleLabel(point1:CGPoint, point2:CGPoint, point3:CGPoint) {
        let midPoint = CGPoint(x: (point1.x + point3.x) / 2, y: (point1.y + point3.y) / 2)
        let distanceToMidPoint = Math.getDistanceBetweenPoints(point2, b: midPoint)
        let ratio = 30.0 / distanceToMidPoint
        let labelCenterPoint = CGPoint(x: ((1.0-ratio) * point2.x) + (ratio * midPoint.x), y: ((1.0-ratio) * point2.y) + (ratio * midPoint.y))

        
        let labelWidth = CGFloat(100)
        let labelHeight = fontSize
        let textLayer = CATextLayer()
        textLayer.font = UIFont(name: font, size: fontSize)
        textLayer.fontSize = fontSize
        textLayer.frame = CGRect(x: labelCenterPoint.x - (labelWidth/2), y: labelCenterPoint.y - (labelHeight/2), width: labelWidth, height: labelHeight)
        textLayer.foregroundColor = pointColors[(angleLabelTextLayers.count + 1) % pointColors.count].CGColor
        textLayer.alignmentMode = kCAAlignmentCenter
        
        let angle = Math.getAcuteAngleInDegrees(point1, point2: point2, point3: point3)
        let roundedAngle = round(angle * 100) / 100
        textLayer.string = String(roundedAngle) + "\u{00B0}"
        frameImageView.layer.addSublayer(textLayer)
        angleLabelTextLayers.append(textLayer)
    }
    
    private func clearAngleLabelsFromScreen() {
        for angleLabelTextLayer in angleLabelTextLayers {
            angleLabelTextLayer.removeFromSuperlayer()
        }
        angleLabelTextLayers.removeAll()
    }
    
    // MARK: Normalization of Points
    
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
    
    // MARK: Other Utils
    
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

