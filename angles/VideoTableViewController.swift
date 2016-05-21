//
//  VideoTableViewController.swift
//  angles
//
//  Created by Nathan on 4/24/16.
//  Copyright © 2016 Nathan. All rights reserved.
//
import UIKit
import MobileCoreServices

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
        
        let formatter = NSDateFormatter()
        formatter.dateStyle = .LongStyle
        formatter.timeStyle = .ShortStyle
        cell.dateLabel.text = formatter.stringFromDate(video.dateCreated)
        
        return cell
    }

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
        
        do {
            // Create a new video object. This initializer will move the video from the
            // temp directory to our application's video files directory:
            let video = try Video(tempVideoURL: videoURL!)
            
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
        
        // Check whether camera is avilable:
        if !UIImagePickerController.isSourceTypeAvailable(.Camera) {
            displayErrorAlert("Camera not available")
            return
        }
        if !UIImagePickerController.isCameraDeviceAvailable(.Rear) {
            displayErrorAlert("Rear camera not available")
            return
        }
        
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .Camera
        imagePickerController.mediaTypes = [kUTTypeMovie as String]
        imagePickerController.cameraCaptureMode = .Video
        imagePickerController.cameraDevice = .Rear
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
