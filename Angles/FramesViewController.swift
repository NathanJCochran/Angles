//
//  ViewController.swift
//  Angles
//
//  Created by Nathaniel J Cochran on 4/24/16.
//  Copyright © 2016 Nathaniel J Cochran. All rights reserved.
//

import UIKit
import CoreMedia
import AVKit
import AVFoundation

class FramesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    let pointDiameterModifier = CGFloat(0.042)
    let angleToPointDistance = CGFloat(35.0)
    let font = "Helvetica"
    let fontSize = CGFloat(14.0)
    
    // MARK: Properties
    var video: Video!
    var currentFrame: Frame!
    var player: AVPlayer!
    var playerLayer: AVPlayerLayer!
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
    
    // MARK: Outlets
    @IBOutlet weak var deleteFrameButton: UIBarButtonItem!
    @IBOutlet weak var undoButton: UIBarButtonItem!
    @IBOutlet weak var exportButton: UIBarButtonItem!
    @IBOutlet weak var frameVideoView: UIView!
    @IBOutlet weak var frameSlider: UISlider!
    @IBOutlet weak var frameStepper: UIStepper!
    @IBOutlet weak var videoDurationLabel: UILabel!
    @IBOutlet weak var frameCollectionView: UICollectionView!

    override func viewDidLoad() {
        print("FramesViewController viewDidLoad")
        super.viewDidLoad()

        // Make sure video was properly set:
        if video == nil {
            displayErrorAlert("video field not properly set")
            return
        }
        
        // Create AVPlayer for video:
        player = AVPlayer(url: video.videoURL)
        
        // Save references to bar button items so we can toggle their existence:
        deleteFrameButtonRef = deleteFrameButton
        undoButtonRef = undoButton
        
        // Load document controller:
        documentController = UIDocumentInteractionController(url: video.getXLSXURL() as URL)
        
        // Set navbar title:
        title = video.name
        
        // Set slider min and max:
        frameSlider.minimumValue = 0
        frameSlider.maximumValue = Float(video.getDuration().seconds)
        
        // Set stepper min and max:
        frameStepper.minimumValue = Double(Int.min)
        frameStepper.maximumValue = Double(Int.max)
        frameStepper.value = 0
        
        // Set current frame to first saved frame or default:
        if video.frames.count > 0 {
            setCurrentFrameTo(video.frames.first!, drawPoints: false)
            frameCollectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: true, scrollPosition: UICollectionViewScrollPosition())
        } else {
            // Default
            setCurrentFrameTo(0)
            frameSlider.value = 0
        }
        
        // Add observer for when user returns after selecting home button.
        // Will check to see if settings have changed, and will update display of angles if so:
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: .UIApplicationWillEnterForeground, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("FramesViewController viewDidAppear")
        if playerLayer != nil {
            playerLayer.removeFromSuperlayer()
        }
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = frameVideoView.bounds
        frameVideoView.layer.addSublayer(playerLayer)
        clearPointsFromScreen()
        clearLinesFromScreen()
        clearAngleLabelsFromScreen()
        drawNormalizedPoints(currentFrame.points)
        drawLinesForNormalizedPoints(currentFrame.points)
        drawAngleLabelsForNormalizedPoints(currentFrame.points)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        print("FramesViewController viewWillDisappear")
        
        // Check if back button was pressed (parent is top of navigation stack):
        if let videoTableViewController = self.navigationController?.topViewController as? VideoTableViewController {
            videoTableViewController.saveVideos(async: true)
            
            for indexPath in videoTableViewController.tableView.indexPathsForVisibleRows ?? [] {
                videoTableViewController.tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        print("FramesViewController didReceiveMemoryWarning")
        super.didReceiveMemoryWarning()
        
        // TODO: Make sure parent view's didReceiveMemoryWarning method also called
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        print("FramesViewController viewWillTransition")
        if playerLayer != nil {
            playerLayer.removeFromSuperlayer()
        }
        clearPointsFromScreen()
        clearLinesFromScreen()
        clearAngleLabelsFromScreen()
        coordinator.animate(alongsideTransition: nil, completion: {
            _ in
            self.playerLayer = AVPlayerLayer(player: self.player)
            self.playerLayer.frame = self.frameVideoView.bounds
            self.frameVideoView.layer.addSublayer(self.playerLayer)
            self.drawNormalizedPoints(self.currentFrame.points)
            self.drawLinesForNormalizedPoints(self.currentFrame.points)
            self.drawAngleLabelsForNormalizedPoints(self.currentFrame.points)
        })
    }
    
    func willEnterForeground() {
        print("FramesViewController willEnterForeground")
        
        // Redraw angle labels (or don't), in case settings changed:
        clearAngleLabelsFromScreen()
        if displayAngleLabels() {
            drawAngleLabelsForNormalizedPoints(currentFrame.points)
        }
    }
    
    deinit {
        print("FramesViewController deallocated")
    }
    
    // MARK: Actions
    
    @IBAction func sliderMoved(_ sender: UISlider) {
        print("sliderMoved: sender.value=\(sender.value)")
        let seconds = Double(sender.value)
        setCurrentFrameTo(seconds)
    }
    
    @IBAction func stepperPressed(_ sender: UIStepper) {
        print("stepperPressed: sender.value=\(sender.value)")
        stepCurrentFrame(Int(sender.value))
        frameStepper.value = 0
    }
    
    @IBAction func selectPoint(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: frameVideoView)
        print("selectPoint: location=\(location)")
        
        if playerLayer.videoRect.contains(location) {
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
            }
        }
    }
    
    func movePoint(_ sender:UIPanGestureRecognizer) {
        // Figure out what the new point is:
        let translation = sender.translation(in: frameVideoView)
        let newPoint = CGPoint(x: CGFloat(sender.view!.center.x + translation.x), y: CGFloat(sender.view!.center.y + translation.y))
        
        // If it's out of bounds, stop:
        if !playerLayer.videoRect.contains(newPoint) {
            return
        }
        
        // Update the current frame's point:
        let pointIdx = sender.view!.tag
        currentFrame.points[pointIdx] = normalizePoint(newPoint)
        
        // Move the point view:
        sender.view!.center = newPoint
        sender.setTranslation(CGPoint.zero, in: frameVideoView)
        
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
    }
    
    @IBAction func deleteFrameButtonPressed(_ sender: AnyObject) {
        deleteCurrentFrame()
    }
    
    @IBAction func export(_ sender: UIBarButtonItem) {
        do {
            try video.saveXLSX()
            documentController.presentOptionsMenu(from: exportButton, animated: true)
        } catch {
            displayErrorAlert(error.localizedDescription)
        }
    }
    
    // MARK: UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return video.frames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellIdentifier = "FrameCollectionViewCell"
        let cell = frameCollectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! FrameCollectionViewCell
        let frame = video.frames[(indexPath as NSIndexPath).item]
        
        // Set the image asynchronously, because it can take awhile to generate:
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let image =  try frame.getThumbnailImage(video:self.video, size:cell.frameImageView.frame.size)
                DispatchQueue.main.async {
                    cell.frameImageView.image = image
                }
            } catch {
                DispatchQueue.main.async {
                    self.displayErrorAlert(error.localizedDescription)
                }
            }
        }
        
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
    }
    
    fileprivate func setCurrentFrameTo(_ frame: Frame, drawPoints: Bool = true) {
        toggleUndoAndDeleteButtons(true)
        clearPointsFromScreen()
        clearLinesFromScreen()
        clearAngleLabelsFromScreen()
        let time = CMTime(seconds:frame.seconds, preferredTimescale: video.getDuration().timescale)
        player.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        setVideoTimeLabel(frame.seconds)
        setSlider(frame.seconds)
        if drawPoints {
            drawNormalizedPoints(frame.points)
            drawLinesForNormalizedPoints(frame.points)
            drawAngleLabelsForNormalizedPoints(frame.points)
        }
        currentFrame = frame
    }

    fileprivate func setCurrentFrameTo(_ seconds: Double) {
        toggleUndoAndDeleteButtons(false)
        clearPointsFromScreen()
        clearLinesFromScreen()
        clearAngleLabelsFromScreen()
        clearFrameSelection()
        let time = CMTime(seconds:seconds, preferredTimescale: video.getDuration().timescale)
        player.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        setVideoTimeLabel(seconds)
        currentFrame = Frame(seconds: seconds)
    }
    
    fileprivate func stepCurrentFrame(_ byCount: Int) {
        toggleUndoAndDeleteButtons(false)
        clearPointsFromScreen()
        clearLinesFromScreen()
        clearAngleLabelsFromScreen()
        clearFrameSelection()
        player.currentItem!.step(byCount: byCount)
        let seconds = player.currentTime().seconds
        setVideoTimeLabel(seconds)
        setSlider(seconds)
        currentFrame = Frame(seconds: seconds)
    }
    
    fileprivate func setVideoTimeLabel(_ totalSeconds:Double) {
        // TODO: Better time format. Fractions of a second? Milliseconds? Display hours, minutes depending on context?
        let hours = Int(floor(totalSeconds / 3600))
        let minutes = Int(floor(totalSeconds.truncatingRemainder(dividingBy: 3600) / 60))
        let seconds = Int(floor((totalSeconds.truncatingRemainder(dividingBy: 3600)).truncatingRemainder(dividingBy: 60)))
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
        let pointDiameter = min(playerLayer.videoRect.size.width, playerLayer.videoRect.size.height) * pointDiameterModifier
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
        
        // Add point view to frameVideoView:
        frameVideoView.addSubview(pointView)
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
        frameVideoView.layer.addSublayer(shapeLayer)
        lineShapeLayers.append(shapeLayer)
    }
    
    fileprivate func redrawLine(_ lineIdx: Int, point1: CGPoint, point2: CGPoint) {
        lineShapeLayers[lineIdx].removeFromSuperlayer()
        let newLineShapeLayer = getLineShapeLayer(point1, point2: point2)
        frameVideoView.layer.addSublayer(newLineShapeLayer)
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
    
    fileprivate func displayAngleLabels() -> Bool {
        return UserDefaults.standard.bool(forKey: "display_angles_preference")
    }
    
    fileprivate func drawAngleLabel(_ point1:CGPoint, point2:CGPoint, point3:CGPoint) {
        if displayAngleLabels() {
            let textLayer = getAngleLabelTextLayer(point1, point2:point2, point3:point3)
            textLayer.foregroundColor = pointColors[(angleLabelTextLayers.count + 1) % pointColors.count].cgColor
            frameVideoView.layer.addSublayer(textLayer)
            angleLabelTextLayers.append(textLayer)
        }
    }
    
    fileprivate func redrawAngleLabel(_ angleIdx: Int, point1: CGPoint, point2:CGPoint, point3:CGPoint) {
        if displayAngleLabels() {
            angleLabelTextLayers[angleIdx].removeFromSuperlayer()
            let newAngleLabelTextLayer = getAngleLabelTextLayer(point1, point2:point2, point3:point3)
            newAngleLabelTextLayer.foregroundColor = pointColors[(angleIdx + 1) % pointColors.count].cgColor
            frameVideoView.layer.addSublayer(newAngleLabelTextLayer)
            angleLabelTextLayers[angleIdx] = newAngleLabelTextLayer
        }
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
        textLayer.string = String(describing: roundedAngle) + "\u{00B0}"
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
        let adjustedPoint = CGPoint(x: point.x - playerLayer.videoRect.minX, y: point.y - playerLayer.videoRect.minY)
        let scaledPoint = CGPoint(
            x: (adjustedPoint.x / playerLayer.videoRect.width) * video.getVideoSize().width,
            y: (adjustedPoint.y / playerLayer.videoRect.height) * video.getVideoSize().height
        )
        return scaledPoint
    }
    
    fileprivate func denormalizePoint(_ point:CGPoint) -> CGPoint{
        let adjustedPoint = CGPoint(
            x: (point.x / video.getVideoSize().width) * playerLayer.videoRect.width,
            y: (point.y / video.getVideoSize().height) * playerLayer.videoRect.height
        )
        let realPoint = CGPoint(x: adjustedPoint.x + playerLayer.videoRect.minX, y: adjustedPoint.y + playerLayer.videoRect.minY)
        return realPoint
    }
    
    // MARK: Other Utils
    
    fileprivate func displayErrorAlert(_ message: String) {
        print(message)
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

