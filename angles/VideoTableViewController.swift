//
//  VideoTableViewController.swift
//  angles
//
//  Created by Nathan on 4/24/16.
//  Copyright © 2016 Nathan. All rights reserved.
//
import UIKit
import MobileCoreServices
import Photos

class VideoTableViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, SaveVideoDelegate {
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
        
        return cell
    }

    // Edit mode:
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete video file from user's Documents directory:
            let video = videos[indexPath.row]
            do {
                let fileManager = NSFileManager.defaultManager()
                try fileManager.removeItemAtURL(video.videoURL)
            } catch let error as NSError {
                displayErrorAlert("Could not delete file from Documents directory")
                print(error)
                return
            }
            
            // Remove video object from list:
            videos.removeAtIndex(indexPath.row)
            saveVideos()
            
            // Remove video from table view:
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
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
            self.videos.append(video!)
            saveVideos()
            
            // Make it display in the table view:
            let newIndexPath = NSIndexPath(forRow: self.videos.count-1, inSection: 0)
            self.tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Bottom)
            
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
        let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
        dispatch_async(backgroundQueue, {
            do {
                try Video.SaveVideos(self.videos)
            } catch Video.VideoError.SaveError(let message, let error) {
                dispatch_async(dispatch_get_main_queue(), {
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
}
