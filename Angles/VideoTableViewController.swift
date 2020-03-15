//
//  VideoTableViewController.swift
//  Angles
//
//  Created by Nathaniel J Cochran on 4/24/16.
//  Copyright © 2016 Nathaniel J Cochran. All rights reserved.
//
import UIKit
import MobileCoreServices
import Photos

class VideoTableViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate,  UITextFieldDelegate {
    
    var videos = [Video]()
    
    // MARK: Outlets
    @IBOutlet weak var addButton: UIBarButtonItem!

    override func viewDidLoad() {
        print("VideoTableViewController viewDidLoad")
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        
        // Video.ClearSavedVideos() // WARNING: Erases ALL user data
        
        print("loading videos")
        videos = Video.LoadVideos()
        print("videos loaded")
        
        // Add observers for when the app enters the background or terminates:
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willTerminate), name: UIApplication.willTerminateNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        print("VideoTableViewController viewWillAppear")
    }

    override func didReceiveMemoryWarning() {
        print("VideoTableViewController didReceiveMemoryWarning")
        super.didReceiveMemoryWarning()
        freeMemory()
    }
    
    @objc func didEnterBackground() {
        print("VideoTableViewController didEnterBackground")
        saveVideos(async: false)
        freeMemory()
    }
    
    @objc func willTerminate() {
        print("VideoTableViewController willTerminate")
        saveVideos(async:false)
    }
    
    deinit {
        print("VideoTableViewController deallocated")
    }
    
    // MARK: UITableViewDataSource

    // Setup:
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videos.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "VideoTableViewCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! VideoTableViewCell
        let video = videos[(indexPath as NSIndexPath).row]
        
        cell.nameLabel.text = video.name
        cell.dateLabel.text = video.getFormattedDateCreated()
        cell.nameTextField.text = video.name
        cell.nameTextField.isHidden = true
        cell.nameTextField.delegate = self
        
        // Set the image asynchronously, because it can take awhile to generate:
        let size = cell.thumbnailImage.frame.size // Can't access from background thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let image = try video.getThumbnailImage(size: size)
                DispatchQueue.main.async {
                    cell.thumbnailImage.image = image
                }
            } catch {
                DispatchQueue.main.async {
                    self.displayErrorAlert(error.localizedDescription)
                }
            }
        }
        
        return cell
    }

    // Edit mode:
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        // Delete Action:
        let deleteAction = UITableViewRowAction(style: .normal, title: "Delete", handler: {action,indexPath in
            let video = self.videos[(indexPath as NSIndexPath).row]
            do {
                // Delete video data from user's Documents directory:
                try video.deleteData()
            } catch {
                self.displayErrorAlert(error.localizedDescription)
            }
            
            // Remove video object from list:
            self.videos.remove(at: (indexPath as NSIndexPath).row)
            
            // Remove video from table view:
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            // Save videos:
            self.saveVideos(async: true)
        })
        deleteAction.backgroundColor = UIColor(red: 0.9, green: 0, blue: 0, alpha: 1.0)
        
        // Edit Action:
        let editAction = UITableViewRowAction(style: .normal, title: " Edit  ", handler: {action,indexPath in
            self.editNameTextFieldAt(indexPath)
        })
        editAction.backgroundColor = UIColor(red: 0, green: 0.7, blue: 0, alpha: 1.0)
        
        return [deleteAction, editAction]
    }
    
    func editNameTextFieldAt(_ indexPath: IndexPath, highlightText: Bool = false) {
        let cell = tableView.cellForRow(at: indexPath) as! VideoTableViewCell
        let textField = cell.nameTextField
        
        // Hide name label:
        cell.nameLabel.isHidden = true
        
        // Show text field:
        textField?.tag = (indexPath as NSIndexPath).row
        textField?.text = cell.nameLabel.text
        textField?.isHidden = false
        
        // This has to be queued up to work (seems like it has to wait for
        // the animation of the row sliding back into position to finish):
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.9) {
            textField?.becomeFirstResponder()
            if highlightText {
                textField?.selectedTextRange = textField?.textRange(from: (textField?.beginningOfDocument)!, to: (textField?.endOfDocument)!)
            }
        }
        
        // Scroll to the row:
        tableView.scrollToRow(at: indexPath, at: .top , animated: true)
        
        // Stop edit mode:
        stopEditMode()
    }
    
    func stopEditMode() {
        // Turn off edit mode (doesn't always work if still in the process of transitioning
        // to edit mode from swipe. It is therefore called again after a short delay):
        setEditing(false, animated: true)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            self.setEditing(false, animated: true)
        }
    }
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let indexPath = IndexPath(row: textField.tag, section: 0)
        let cell = tableView.cellForRow(at: indexPath) as! VideoTableViewCell
        
        // If text field is not empty:
        if cell.nameTextField.text != nil && cell.nameTextField.text != "" {
            
            // Update video model and name label:
            cell.nameLabel.text = cell.nameTextField.text!
            videos[(indexPath as NSIndexPath).row].name = cell.nameTextField.text!
            saveVideos(async:true)
        }
        
        // Hide text field, display label:
        cell.nameTextField.isHidden = true
        cell.nameLabel.isHidden = false
        
        // Make sure editing mode is off:
        // (in case it didn't work the first time, in editActionsForRowAtIndexPath)
        setEditing(false, animated: true)
    }

    // MARK: UIImagePickerControllerDelegate
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController){
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]){
        
        // Get the URL of the video in the tmp directory:
        let videoURL = info[UIImagePickerController.InfoKey.mediaURL] as? URL
        if videoURL == nil {
            // Dismiss the image picker controller:
            dismiss(animated: true, completion: nil)
            displayErrorAlert("Could not get video URL")
            return
        }
        
        // Get the creation date of the video, or the default (now):
        var dateCreated = Date()
        if let referenceURL = info[UIImagePickerController.InfoKey.referenceURL] as? URL {
            if let libraryVideoAsset = PHAsset.fetchAssets(withALAssetURLs: [referenceURL], options: nil).firstObject as PHAsset? {
                dateCreated = libraryVideoAsset.creationDate ?? Date()
            }
        }
        
        do {
            // Create a new video object. This initializer will move the video from the
            // temp directory to our application's video files directory:
            let video = try Video(tempVideoURL: videoURL!, dateCreated: dateCreated)
            
            // Add new video to the list:
            videos.insert(video, at: 0)
            
            // Make it display in the table view:
            let newIndexPath = IndexPath(row: 0, section: 0)
            tableView.insertRows(at: [newIndexPath], with: .top)
            tableView.scrollToRow(at: newIndexPath, at: .top, animated: true)
            editNameTextFieldAt(newIndexPath, highlightText: true)
        } catch {
            // Dismiss the image picker controller:
            dismiss(animated: true, completion: nil)
            displayErrorAlert(error.localizedDescription)
            return
        }
        
        // Dismiss the image picker controller:
        dismiss(animated: true, completion: nil)
    }
    
    
    // MARK: Actions
    
    @IBAction func addVideo(_ sender: UIBarButtonItem) {
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        if UIImagePickerController.isSourceTypeAvailable(.camera) && UIImagePickerController.isCameraDeviceAvailable(.rear) && UIImagePickerController.availableMediaTypes(for: .camera)?.contains(kUTTypeMovie as String) ?? false {
            menu.addAction(UIAlertAction(title: "Camera", style: .default, handler: {_ in self.presentImagePickerController(.camera)}))
        }
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            menu.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: {_ in self.presentImagePickerController(.photoLibrary)}))
        }
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(menu, animated: true, completion: nil)
    }
    
    fileprivate func presentImagePickerController(_ sourceType: UIImagePickerController.SourceType) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = sourceType
        imagePickerController.mediaTypes = [kUTTypeMovie as String]
        if sourceType == .camera {
            imagePickerController.cameraCaptureMode = .video
            imagePickerController.cameraDevice = .rear
            imagePickerController.cameraFlashMode = .auto
        }
        imagePickerController.allowsEditing = false
        imagePickerController.delegate = self
        
        if sourceType == .photoLibrary &&
            UIDevice.current.userInterfaceIdiom == .pad {
            imagePickerController.modalPresentationStyle = .popover
            imagePickerController.popoverPresentationController!.barButtonItem = self.addButton
            present(imagePickerController, animated: true, completion: nil)
        } else {
            present(imagePickerController, animated: true, completion: nil)
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowFrames" {
            let framesViewController = segue.destination as! FramesViewController
            let selectedVideoCell = sender as! VideoTableViewCell
            let indexPath = tableView.indexPath(for: selectedVideoCell)!
            framesViewController.video = videos[(indexPath as NSIndexPath).row]
        }
    }
    
    // MARK: Helper methods
    
    func displayErrorAlert(_ message: String) {
        print(message)
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: Persistence
    
    func saveVideos(async: Bool) {
        if async {
            // Asynchronous version:
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    print("saving videos")
                    try Video.SaveVideos(self.videos)
                    print("videos saved")
                } catch {
                    DispatchQueue.main.async {
                        self.displayErrorAlert(error.localizedDescription)
                    }
                }
            }
        } else {
            // Synchronous version:
            do {
                print("saving videos")
                try Video.SaveVideos(videos)
                print("videos saved")
            } catch {
                displayErrorAlert(error.localizedDescription)
            }
        }
    }
    
    func freeMemory() {
        print("freeing memory")
        for video in videos {
            video.freeMemory()
        }
        print("memory freed")
    }
}
