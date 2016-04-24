//
//  VideoTableViewController.swift
//  angles
//
//  Created by Nathan on 4/24/16.
//  Copyright © 2016 Nathan. All rights reserved.
//

import UIKit
import MobileCoreServices

class VideoTableViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var videos = [Video]()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.leftBarButtonItem = self.editButtonItem()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: Table View Data Source

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
        cell.dateLabel.text = video.dateCreated.description
        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            videos.removeAtIndex(indexPath.row)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    
    // MARK: UIImagePickerControllerDelegate
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController){
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]){
        
        // Dismiss the image picker controller:
        dismissViewControllerAnimated(true, completion: nil)
        
        // Add it to the list:
        let videoURL = info[UIImagePickerControllerMediaURL] as! NSURL
        let video = Video(name: "Untitled", dateCreated: NSDate(), videoURL: videoURL)
        videos.append(video!)
        
        // Make it display in the table view:
        let newIndexPath = NSIndexPath(forRow: videos.count-1, inSection: 0)
        tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Bottom)
    }
    
    // MARK: Actions
    
    @IBAction func addVideo(sender: UIBarButtonItem) {
        
        // Check whether camera is avilable:
        if !UIImagePickerController.isSourceTypeAvailable(.Camera) {
            displayAlert("Error", message: "Camera not available")
            return
        }
        if UIImagePickerController.isCameraDeviceAvailable(.Rear) {
            displayAlert("Error", message: "Rear camera not available")
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
    
    // MARK: Helper methods
    
    func displayAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
    }
    

    
    // MARK: - Navigation

    /*
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
