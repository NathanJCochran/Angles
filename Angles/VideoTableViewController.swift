//
//  VideoTableViewController.swift
//  Angles
//
//  Created by Nathan on 4/24/16.
//  Copyright © 2016 Nathan. All rights reserved.
//
import UIKit
import MobileCoreServices
import Photos

class VideoTableViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate,  UITextFieldDelegate, SaveVideoDelegate {
    var videos = [Video]()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = self.editButtonItem()
        
        // Video.ClearSavedVideos()
        videos = Video.LoadVideos()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    
    // MARK: UITableViewDataSource

    // Setup:
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videos.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellIdentifier = "VideoTableViewCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! VideoTableViewCell
        let video = videos[indexPath.row]
        
        cell.nameLabel.text = video.name
        cell.dateLabel.text = video.getFormattedDateCreated()
        cell.thumbnailImage.image = video.getThumbnailImage()
        cell.nameTextField.text = video.name
        cell.nameTextField.hidden = true
        cell.nameTextField.delegate = self
        
        return cell
    }

    // Edit mode:
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        
        // Delete Action:
        let deleteAction = UITableViewRowAction(style: .Normal, title: "Delete", handler: {action,indexPath in
            let video = self.videos[indexPath.row]
            do {
                // Delete video data from user's Documents directory:
                try video.deleteData()
            } catch Video.VideoError.SaveError(let message, let error) {
                self.displayErrorAlert(message)
                if error != nil {
                    print(error)
                }
            } catch let error as NSError {
                self.displayErrorAlert("Could not delete video data")
                print(error)
            }
            
            // Remove video object from list:
            self.videos.removeAtIndex(indexPath.row)
            self.saveVideos()
            
            // Remove video from table view:
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)

        })
        deleteAction.backgroundColor = UIColor(red: 0.9, green: 0, blue: 0, alpha: 1.0)
        
        // Edit Action:
        let editAction = UITableViewRowAction(style: .Normal, title: " Edit  ", handler: {action,indexPath in
            self.editNameTextFieldAt(indexPath)
        })
        editAction.backgroundColor = UIColor(red: 0, green: 0.7, blue: 0, alpha: 1.0)
        
        return [deleteAction, editAction]
    }
    
    func editNameTextFieldAt(indexPath: NSIndexPath, highlightText: Bool = false) {
        let cell = tableView.cellForRowAtIndexPath(indexPath) as! VideoTableViewCell
        let textField = cell.nameTextField
        
        // Hide name label:
        cell.nameLabel.hidden = true
        
        // Show text field:
        textField.tag = indexPath.row
        textField.text = cell.nameLabel.text
        textField.hidden = false
        textField.becomeFirstResponder()
        if highlightText {
            // Not sure why, but this has to be queued up to work:
            delay(0.1, fn: {
                textField.selectedTextRange = textField.textRangeFromPosition(textField.beginningOfDocument, toPosition: textField.endOfDocument)
            })
        }
        
        // Scroll to the row:
        tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: .Top , animated: true)
        
        // Stop edit mode:
        stopEditMode()
    }
    
    func stopEditMode() {
        // Turn off edit mode (doesn't always work if still in the process of transitioning
        // to edit mode from swipe. It is therefore called again after a short delay):
        setEditing(false, animated: true)
        delay(0.1, fn: {
            self.setEditing(false, animated: true)
        })
    }
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        let indexPath = NSIndexPath(forRow: textField.tag, inSection: 0)
        let cell = tableView.cellForRowAtIndexPath(indexPath) as! VideoTableViewCell
        
        // If text field is not empty:
        if cell.nameTextField.text != nil && cell.nameTextField.text != "" {
            
            // Update video model and name label:
            cell.nameLabel.text = cell.nameTextField.text!
            videos[indexPath.row].name = cell.nameTextField.text!
            saveVideos()
        }
        
        // Hide text field, display label:
        cell.nameTextField.hidden = true
        cell.nameLabel.hidden = false
        
        // Make sure editing mode is off:
        // (in case it didn't work the first time, in editActionsForRowAtIndexPath)
        setEditing(false, animated: true)
    }

    // MARK: UIImagePickerControllerDelegate
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController){
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]){
        
        // Dismiss the image picker controller:
        dismissViewControllerAnimated(true, completion: nil)
        
        // Get the URL of the video in the tmp directory:
        let videoURL = info[UIImagePickerControllerMediaURL] as? NSURL
        if videoURL == nil {
            displayErrorAlert("Could not get video URL")
            return
        }
        
        // Get the creation date of the video, or the default (now):
        var dateCreated = NSDate()
        if let referenceURL = info[UIImagePickerControllerReferenceURL] as? NSURL {
            if let libraryVideoAsset = PHAsset.fetchAssetsWithALAssetURLs([referenceURL], options: nil).firstObject as? PHAsset {
                dateCreated = libraryVideoAsset.creationDate ?? NSDate()
            }
        }
        
        do {
            // Create a new video object. This initializer will move the video from the
            // temp directory to our application's video files directory:
            let video = try Video(tempVideoURL: videoURL!, dateCreated: dateCreated)
            
            // Add new video to the list:
            videos.insert(video, atIndex: 0)
            saveVideos()
            
            // Make it display in the table view:
            let newIndexPath = NSIndexPath(forRow: 0, inSection: 0)
            tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Top)
            tableView.scrollToRowAtIndexPath(newIndexPath, atScrollPosition: .Top, animated: true)
            editNameTextFieldAt(newIndexPath, highlightText: true)
        } catch Video.VideoError.SaveError(let message, let error) {
            displayErrorAlert(message)
            if error != nil {
                print(error)
            }
        } catch let error as NSError {
            displayErrorAlert("Something went wrong while attempting to save new video")
            print(error)
        }
    }
    
    
    // MARK: Actions
    
    @IBAction func addVideo(sender: UIBarButtonItem) {
        
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .Alert)
        if UIImagePickerController.isSourceTypeAvailable(.Camera) && UIImagePickerController.isCameraDeviceAvailable(.Rear) {
            menu.addAction(UIAlertAction(title: "Camera", style: .Default, handler: {_ in self.presentImagePickerController(.Camera)}))
        }
        if UIImagePickerController.isSourceTypeAvailable(.PhotoLibrary) {
            menu.addAction(UIAlertAction(title: "Photo Library", style: .Default, handler: {_ in self.presentImagePickerController(.PhotoLibrary)}))
        }
        menu.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        presentViewController(menu, animated: true, completion: nil)
    }
    
    private func presentImagePickerController(sourceType: UIImagePickerControllerSourceType) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = sourceType
        imagePickerController.mediaTypes = [kUTTypeMovie as String]
        if sourceType == .Camera {
            imagePickerController.cameraCaptureMode = .Video
            imagePickerController.cameraDevice = .Rear
        }
        imagePickerController.allowsEditing = false
        imagePickerController.delegate = self
        presentViewController(imagePickerController, animated: true, completion: nil)
    }
    
    // MARK: - Navigation
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowFrames" {
            let framesViewController = segue.destinationViewController as! FramesViewController
            let selectedVideoCell = sender as! VideoTableViewCell
            let indexPath = tableView.indexPathForCell(selectedVideoCell)!
            framesViewController.video = videos[indexPath.row]
            framesViewController.saveDelegate = self
        }
    }
    
    // MARK: Helper methods
    
    func displayErrorAlert(message: String) {
        print(message)
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
    }
    
    
    // MARK: Persistence
    
    func saveVideos() {
        background({
            do {
                try Video.SaveVideos(self.videos)
            } catch Video.VideoError.SaveError(let message, let error) {
                self.async({
                    self.displayErrorAlert(message)
                    if error != nil {
                        print(error)
                    }
                })
            } catch let error as NSError {
                dispatch_async(dispatch_get_main_queue(), {
                    self.displayErrorAlert("Somethine went wrong while attempting to save videos")
                    print(error)
                })
            }
        })
    }
    
    func async(fn: (() -> Void)) {
        let mainQueue = dispatch_get_main_queue()
        dispatch_async(mainQueue, {
            fn()
        })
    }
    
    func delay(delay:Double, fn :(() -> Void)) {
        let mainQueue = dispatch_get_main_queue()
        let dispatchTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
        dispatch_after(dispatchTime, mainQueue, fn)
    }
    
    func background(fn: (() -> Void)) {
        let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
        dispatch_async(backgroundQueue, {
            fn()
        })
    }
}
