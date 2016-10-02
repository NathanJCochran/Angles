//
//  ViewController.swift
//  Angles
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
    
    let pointDiameterModifier = CGFloat(0.042)
    let angleToPointDistance = CGFloat(35.0)
    let font = "Helvetica"
    let fontSize = CGFloat(14.0)
    
    // MARK: Properties
    
    var video: Video!
    var currentFrame: Frame!
    var videoAsset: AVURLAsset!
    var videoImageGenerator: AVAssetImageGenerator!
    var documentController: UIDocumentInteractionController!
    
    // MARK: References to drawn images:
    var pointViews = [UIView]()
    var lineShapeLayers = [CAShapeLayer]()
    var angleLabelTextLayers = [CATextLayer]()
    
    // MARK: Point colors:
    var pointColors = [UIColor.blue, UIColor.orange, UIColor.green,
                       UIColor.yellow, UIColor.red, UIColor.cyan,
                       UIColor.magenta, UIColor.white]
    
    // MARK: Frame button references for sake of toggle:
    var deleteFrameButtonRef: UIBarButtonItem!
    var undoButtonRef: UIBarButtonItem!
    
    // MARK: Save videos delegate
    var saveDelegate: SaveVideoDelegate!
    
    // MARK: Outlets
    @IBOutlet weak var deleteFrameButton: UIBarButtonItem!
    @IBOutlet weak var undoButton: UIBarButtonItem!
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
        deleteFrameButtonRef = deleteFrameButton
        undoButtonRef = undoButton
        
        // Load video and image generator:
        videoAsset = AVURLAsset(url: video.videoURL as URL, options: nil)
        videoImageGenerator = AVAssetImageGenerator(asset: videoAsset)
        videoImageGenerator.appliesPreferredTrackTransform = true
        videoImageGenerator.requestedTimeToleranceBefore = kCMTimeZero
        videoImageGenerator.requestedTimeToleranceAfter = kCMTimeZero
        
        // Load document controller:
        documentController = UIDocumentInteractionController(url: video.getXLSXURL() as URL)
        
        // Set navbar title:
        title = video.name
        
        // Set slider min and max:
        frameSlider.minimumValue = 0
        frameSlider.maximumValue = Float(videoAsset.duration.seconds)
        
        // Set current frame to first saved frame or default:
        if video.frames.count > 0 {
            setCurrentFrameTo(video.frames.first!, drawPoints: false)
            frameCollectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: true, scrollPosition: UICollectionViewScrollPosition())
        } else {
            // Default
            setCurrentFrameTo(0)
            frameSlider.value = 0
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        clearPointsFromScreen()
        clearLinesFromScreen()
        clearAngleLabelsFromScreen()
        coordinator.animate(alongsideTransition: nil, completion: {
            _ in
            self.drawNormalizedPoints(self.currentFrame.points)
            self.drawLinesForNormalizedPoints(self.currentFrame.points)
            self.drawAngleLabelsForNormalizedPoints(self.currentFrame.points)
        })
    }
    
    // MARK: Actions
    
    @IBAction func sliderMoved(_ sender: UISlider) {
        let seconds = Double(sender.value)
        setCurrentFrameTo(seconds)
    }
    
    @IBAction func selectPoint(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: frameImageView)
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
            if currentFrame.points.count == 1 {
                saveCurrentFrame()
            } else {
                saveDelegate.saveVideos()
            }
        }
    }
    
    func movePoint(_ sender:UIPanGestureRecognizer) {
        // Figure out what the new point is:
        let translation = sender.translation(in: frameImageView)
        let newPoint = CGPoint(x: CGFloat(sender.view!.center.x + translation.x), y: CGFloat(sender.view!.center.y + translation.y))
        
        // If it's out of bounds, stop:
        let frameImageRect = getFrameImageRect()
        if !frameImageRect.contains(newPoint) {
            return
        }
        
        // Update the current frame's point:
        let pointIdx = sender.view!.tag
        currentFrame.points[pointIdx] = normalizePoint(newPoint)
        
        // Move the point view:
        sender.view!.center = newPoint
        sender.setTranslation(CGPoint.zero, in: frameImageView)
        
        // Redraw the lines:
        if pointIdx > 0 {
            redrawLine(pointIdx-1, point1: denormalizePoint(currentFrame.points[pointIdx-1]), point2: newPoint)
        }
        if pointIdx < currentFrame.points.count - 1 {
            redrawLine(pointIdx, point1: newPoint, point2: denormalizePoint(currentFrame.points[pointIdx+1]))
        }
        
        // Redraw the angle labels:
        if pointIdx > 1 {
            redrawAngleLabel(pointIdx-2, point1: denormalizePoint(currentFrame.points[pointIdx-2]), point2: denormalizePoint(currentFrame.points[pointIdx-1]), point3: newPoint)
        }
        if pointIdx > 0 && pointIdx < currentFrame.points.count - 1 {
            redrawAngleLabel(pointIdx-1, point1: denormalizePoint(currentFrame.points[pointIdx-1]), point2: newPoint, point3: denormalizePoint(currentFrame.points[pointIdx+1]))
        }
        if pointIdx < currentFrame.points.count - 2{
            redrawAngleLabel(pointIdx, point1: newPoint, point2: denormalizePoint(currentFrame.points[pointIdx+1]), point3: denormalizePoint(currentFrame.points[pointIdx+2]))
        }
    }
    
    @IBAction func undoPoint(_ sender: UIBarButtonItem) {
        currentFrame.points.removeLast()
        if let pointView = pointViews.popLast() {
            pointView.removeFromSuperview()
        }
        if let lineShapeLayer = lineShapeLayers.popLast() {
            lineShapeLayer.removeFromSuperlayer()
        }
        if let angleLabelTextLayer = angleLabelTextLayers.popLast() {
            angleLabelTextLayer.removeFromSuperlayer()
        }
        if currentFrame.points.isEmpty {
            deleteCurrentFrame()
        }
        saveDelegate.saveVideos()
    }
    
    @IBAction func deleteFrameButtonPressed(_ sender: AnyObject) {
        deleteCurrentFrame()
    }
    
    @IBAction func export(_ sender: UIBarButtonItem) {
        do {
            try video.saveXLSX()
            documentController.presentOptionsMenu(from: exportButton, animated: true)
        } catch Video.VideoError.saveError(let message, let error) {
            displayErrorAlert(message)
            if error != nil {
                print(error)
            }
        } catch Video.VideoError.xlsxError(let message, let error) {
            displayErrorAlert(message)
            if error != nil {
                print(error!)
            }
        } catch let error as NSError {
            displayErrorAlert("Something went wrong while attempting to export the data to XLSX format")
            print(error)
        }
    }
    
    // MARK: UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return video.frames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellIdentifier = "FrameCollectionViewCell"
        let cell = frameCollectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! FrameCollectionViewCell
        cell.frameImageView.image = video.frames[(indexPath as NSIndexPath).item].image
        return cell
    }
    
    // MARK: UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let frame = video.frames[(indexPath as NSIndexPath).item]
        setCurrentFrameTo(frame)
    }
    
    // MARK: Set UI Elements:
    
    func saveCurrentFrame() {
        var idx = video.frames.count
        for (i, frame) in video.frames.enumerated() {
            if frame.seconds > currentFrame.seconds {
                idx = i
                break
            }
        }
        video.frames.insert(currentFrame, at: idx)
        let newIndexPath = IndexPath(item: idx, section: 0)
        frameCollectionView.insertItems(at: [newIndexPath])
        frameCollectionView.selectItem(at: newIndexPath, animated: true, scrollPosition: .centeredHorizontally)
        toggleUndoAndDeleteButtons(true)
        saveDelegate.saveVideos()
    }
    
    func deleteCurrentFrame() {
        let selectedItemPath = frameCollectionView.indexPathsForSelectedItems?.first
        if selectedItemPath == nil {
            displayErrorAlert("Could not get index path of currently selected frame")
            return
        }
        video.frames.remove(at: (selectedItemPath! as NSIndexPath).item)
        frameCollectionView.deleteItems(at: [selectedItemPath!])
        currentFrame.points.removeAll()
        clearPointsFromScreen()
        clearLinesFromScreen()
        clearAngleLabelsFromScreen()
        toggleUndoAndDeleteButtons(false)
        saveDelegate.saveVideos()
    }
    
    fileprivate func setCurrentFrameTo(_ frame: Frame, drawPoints: Bool = true) {
        toggleUndoAndDeleteButtons(true)
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
    
    fileprivate func setCurrentFrameTo(_ seconds: Double) {
        do {
            // Generate new frame image from video asset:
            let time = CMTime(seconds:seconds, preferredTimescale: videoAsset.duration.timescale)
            let cgImage = try videoImageGenerator.copyCGImage(at: time, actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            
            toggleUndoAndDeleteButtons(false)
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
    
    fileprivate func setVideoTimeLabel(_ totalSeconds:Double) {
        let hours = Int(floor(totalSeconds / 3600))
        let minutes = Int(floor(totalSeconds.truncatingRemainder(dividingBy: 3600) / 60))
        let seconds = Int(floor((totalSeconds % 3600).truncatingRemainder(dividingBy: 60)))
        videoDurationLabel.text = String(format:"%d:%02d:%02d", hours, minutes, seconds)
    }
    
    fileprivate func setSlider(_ seconds: Double) {
        frameSlider.setValue(Float(seconds), animated: true)
    }
    
    fileprivate func clearFrameSelection() {
        for indexPath in frameCollectionView.indexPathsForSelectedItems! {
            frameCollectionView.deselectItem(at: indexPath, animated: true)
        }
    }
    
    fileprivate func toggleUndoAndDeleteButtons(_ show: Bool) {
        if deleteFrameButtonRef == nil {
            print("deleteFrameButtonRef is nil")
        } else if show {
            navigationItem.setRightBarButtonItems([exportButton, deleteFrameButtonRef, undoButtonRef], animated: true)
        } else {
            navigationItem.setRightBarButtonItems([exportButton], animated: true)
        }
    }
    
    // MARK: Draw Points
    
    fileprivate func drawNormalizedPoints(_ points: [CGPoint]) {
        for point in points {
            drawNormalizedPoint(point)
        }
    }

    fileprivate func drawNormalizedPoint(_ point: CGPoint) {
        drawPoint(denormalizePoint(point))
    }
    
    fileprivate func drawPoint(_ point: CGPoint) {
        
        // Create point shapelayer:
        let pointDiameter = min(getFrameImageRect().size.width, getFrameImageRect().size.height) * pointDiameterModifier
        let shapeLayer = CAShapeLayer()
        let circlePath = UIBezierPath(ovalIn: CGRect(
            x: 0,
            y: 0,
            width: pointDiameter,
            height: pointDiameter
        ))
        shapeLayer.path = circlePath.cgPath
        let color = pointColors[pointViews.count%pointColors.count]
        shapeLayer.strokeColor = color.cgColor
        shapeLayer.fillColor = color.withAlphaComponent(0.5).cgColor
        
        // Create point view containing shapelayer:
        let pointViewRect = CGRect(
            x: point.x - (pointDiameter / 2),
            y: point.y - (pointDiameter / 2),
            width: pointDiameter,
            height: pointDiameter
        )
        let pointView = UIView(frame: pointViewRect)
        pointView.layer.addSublayer(shapeLayer)
        pointView.tag = pointViews.count
        
        // Add gesture recognizer to point view:
        let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(movePoint(_:)))
        pointView.addGestureRecognizer(gestureRecognizer)
        
        // Add point view to frameImageView:
        frameImageView.addSubview(pointView)
        pointViews.append(pointView)
    }
    
    fileprivate func clearPointsFromScreen() {
        for pointView in pointViews {
            pointView.removeFromSuperview()
        }
        pointViews.removeAll()
    }
    
    // MARK: Draw Lines
    
    fileprivate func drawLinesForNormalizedPoints(_ points: [CGPoint]) {
        if points.count > 1 {
            for i in 1..<points.count {
                drawLineForNormalizedPoints(points[i-1], point2: points[i])
            }
        }
    }
    
    fileprivate func drawLineForNormalizedPoints(_ point1: CGPoint, point2: CGPoint) {
        drawLine(denormalizePoint(point1), point2: denormalizePoint(point2))
    }

    
    fileprivate func drawLine(_ point1: CGPoint, point2: CGPoint) {
        let shapeLayer = getLineShapeLayer(point1, point2: point2)
        frameImageView.layer.addSublayer(shapeLayer)
        lineShapeLayers.append(shapeLayer)
    }
    
    fileprivate func redrawLine(_ lineIdx: Int, point1: CGPoint, point2: CGPoint) {
        lineShapeLayers[lineIdx].removeFromSuperlayer()
        let newLineShapeLayer = getLineShapeLayer(point1, point2: point2)
        frameImageView.layer.addSublayer(newLineShapeLayer)
        lineShapeLayers[lineIdx] = newLineShapeLayer
    }
    
    fileprivate func getLineShapeLayer(_ point1: CGPoint, point2: CGPoint) -> CAShapeLayer {
        let path = UIBezierPath()
        path.move(to: point1)
        path.addLine(to: point2)
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.blue.cgColor
        return shapeLayer
    }
    
    fileprivate func clearLinesFromScreen() {
        for lineShapeLayer in lineShapeLayers {
            lineShapeLayer.removeFromSuperlayer()
        }
        lineShapeLayers.removeAll()
    }
    
    // MARK: Draw Angle Labels:
    
    fileprivate func drawAngleLabelsForNormalizedPoints(_ points:[CGPoint]) {
        if points.count > 2 {
            for i in 0..<points.count-2 {
                drawAngleLabelForNormalizedPoints(points[i], point2: points[i+1], point3: points[i+2])
            }
        }
    }
    
    fileprivate func drawAngleLabelForNormalizedPoints(_ point1:CGPoint, point2:CGPoint, point3:CGPoint) {
        drawAngleLabel(denormalizePoint(point1), point2: denormalizePoint(point2), point3: denormalizePoint(point3))
    }
    
    fileprivate func drawAngleLabel(_ point1:CGPoint, point2:CGPoint, point3:CGPoint) {
        let textLayer = getAngleLabelTextLayer(point1, point2:point2, point3:point3)
        textLayer.foregroundColor = pointColors[(angleLabelTextLayers.count + 1) % pointColors.count].cgColor
        frameImageView.layer.addSublayer(textLayer)
        angleLabelTextLayers.append(textLayer)
    }
    
    fileprivate func redrawAngleLabel(_ angleIdx: Int, point1: CGPoint, point2:CGPoint, point3:CGPoint) {
        angleLabelTextLayers[angleIdx].removeFromSuperlayer()
        let newAngleLabelTextLayer = getAngleLabelTextLayer(point1, point2:point2, point3:point3)
        newAngleLabelTextLayer.foregroundColor = pointColors[(angleIdx + 1) % pointColors.count].cgColor
        frameImageView.layer.addSublayer(newAngleLabelTextLayer)
        angleLabelTextLayers[angleIdx] = newAngleLabelTextLayer
    }
    
    fileprivate func getAngleLabelTextLayer(_ point1:CGPoint, point2:CGPoint, point3:CGPoint) -> CATextLayer {
        let midPoint = CGPoint(x: (point1.x + point3.x) / 2, y: (point1.y + point3.y) / 2)
        let distanceToMidPoint = Math.getDistanceBetweenPoints(point2, b: midPoint)
        let ratio = angleToPointDistance / distanceToMidPoint
        let labelCenterPoint = CGPoint(x: ((1.0-ratio) * point2.x) + (ratio * midPoint.x), y: ((1.0-ratio) * point2.y) + (ratio * midPoint.y))
        
        let labelWidth = CGFloat(100)
        let labelHeight = fontSize
        let textLayer = CATextLayer()
        textLayer.font = UIFont(name: font, size: fontSize)
        textLayer.fontSize = fontSize
        textLayer.frame = CGRect(x: labelCenterPoint.x - (labelWidth/2), y: labelCenterPoint.y - (labelHeight/2), width: labelWidth, height: labelHeight)
        textLayer.alignmentMode = kCAAlignmentCenter
        
        let angle = Math.getAcuteAngleInDegrees(point1, point2: point2, point3: point3)
        let roundedAngle = round(angle * 100) / 100
        textLayer.string = String(roundedAngle) + "\u{00B0}"
        return textLayer
    }
    
    
    fileprivate func clearAngleLabelsFromScreen() {
        for angleLabelTextLayer in angleLabelTextLayers {
            angleLabelTextLayer.removeFromSuperlayer()
        }
        angleLabelTextLayers.removeAll()
    }
    
    // MARK: Normalization of Points
    
    fileprivate func normalizePoint(_ point: CGPoint) -> CGPoint {
        let frameImageRect = getFrameImageRect()
        let adjustedPoint = CGPoint(x: point.x - frameImageRect.minX, y: point.y - frameImageRect.minY)
        let scaledPoint = CGPoint(
            x: (adjustedPoint.x / frameImageRect.width) * frameImageView.image!.size.width,
            y: (adjustedPoint.y / frameImageRect.height) * frameImageView.image!.size.height
        )
        return scaledPoint
    }
    
    fileprivate func denormalizePoint(_ point:CGPoint) -> CGPoint{
        let frameImageRect = getFrameImageRect()
        let adjustedPoint = CGPoint(
            x: (point.x / frameImageView.image!.size.width) * frameImageRect.width,
            y: (point.y / frameImageView.image!.size.height) * frameImageRect.height
        )
        let realPoint = CGPoint(x: adjustedPoint.x + frameImageRect.minX, y: adjustedPoint.y + frameImageRect.minY)
        return realPoint
    }
    
    // MARK: Other Utils
    
    fileprivate func getFrameImageRect() -> CGRect {
        let widthRatio = frameImageView.bounds.size.width / frameImageView.image!.size.width
        let heightRatio = frameImageView.bounds.size.height / frameImageView.image!.size.height
        let scale = min(widthRatio, heightRatio)
        let imageWidth = scale * frameImageView.image!.size.width
        let imageHeight = scale * frameImageView.image!.size.height
        let x = (frameImageView.bounds.size.width - imageWidth) / 2
        let y = (frameImageView.bounds.size.height - imageHeight) / 2
        return CGRect(x: x, y: y, width: imageWidth, height: imageHeight)
    }
    
    fileprivate func displayErrorAlert(_ message: String) {
        print(message)
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

