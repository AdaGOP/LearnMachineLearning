//
//  ViewController.swift
//  BeerDetector
//
//  Created by zein rezky chandra on 12/05/20.
//  Copyright © 2020 Apple Developer Academy. All rights reserved.
//

import UIKit
import CoreML
import Vision

class ViewController: UIViewController {

    @IBOutlet weak var pickButton: UIButton! {
        didSet {
            pickButton.layer.cornerRadius = 5.0
            pickButton.layer.masksToBounds = true
        }
    }
    @IBOutlet weak var selectedImage: UIImageView!
    @IBOutlet weak var resultLabel: UILabel!
    
    lazy var analyseRequest: VNCoreMLRequest = { // Create property request to VNCoreML based on ML Model
        do {
            let model = try VNCoreMLModel(for: BeerClassifier().model) // Inisiate the ML Model
            let request = VNCoreMLRequest(model: model, completionHandler: {   [weak self] request, error in
                self?.processToAnalyse(for: request, error: error) // Evaluate the result and update the UI
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func pickAction(_ sender: UIButton) {
        openLibrary() // Func to call image selection from Library
    }
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func openLibrary() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        let actionsheet = UIAlertController(title: "Browse Attachment", message: "Choose A Source", preferredStyle: .alert)
        actionsheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { (action:UIAlertAction)in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                imagePickerController.sourceType = .camera
                self.present(imagePickerController, animated: true, completion: nil)
            } else {
                print("Camera is Not Available")
            }
        }))
        actionsheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { (action:UIAlertAction)in
            imagePickerController.sourceType = .photoLibrary
            imagePickerController.mediaTypes = ["public.image", "public.movie"]
            self.present(imagePickerController, animated: true, completion: nil)
        }))
        actionsheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(actionsheet,animated: true, completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let imageTaken = info[.originalImage] as? UIImage {
//            let newImage = imageTaken.resizeImage(30.0, opaque: false)
            picker.dismiss(animated: true) {
                self.selectedImage.image = imageTaken
                self.createAnalysisRequest(image: imageTaken) // After image selected, create request analysis based on the image
            }
        }
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension ViewController {
    func createAnalysisRequest(image: UIImage) {
        resultLabel.text = "Analyzing..."
        let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue)) // Convert UIImage to CIImage, CIImage are the format compatible with core image filters
        guard let ciImage = CIImage(image: image)
        else {
          fatalError("Unable to create \(CIImage.self) from \(image).") // handle if conversion goes fail
        }
        DispatchQueue.global(qos: .userInitiated).async { // Create under background thread with qos priority, due to heavy task from image processing
           let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation!) // create instance for the request handler
           do {
            try handler.perform([self.analyseRequest]) // perform request based on the handler and analyse it and update the result to UI under main thread
           } catch {
            print("Failed to perform \n\(error.localizedDescription)")
           }
        }
    }
    
    func processToAnalyse(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results
            else {
              self.resultLabel.text = "Unable to analyze image.\n\(error!.localizedDescription)"
              return
            }
            let classifications = results as! [VNClassificationObservation] // create instance for observation returned by VNCoreMLRequests that using a model that is a classifier. A classifier produces an array of classifications which are labels and confidence scores.
            if classifications.isEmpty {
                self.resultLabel.text = "Nothing recognized."
            } else {
                let topClassifications = classifications.prefix(2) // only get 2 important information, which are the confidence value and identifier value
                let descriptions = topClassifications.map { classification in
                    return String(format: "(%.2f) %@", classification.confidence, classification.identifier) // convert the key value from the result and construct into a readable string
                }
                self.resultLabel.text = descriptions.joined(separator: " | ")
            }
        }
    }
}
