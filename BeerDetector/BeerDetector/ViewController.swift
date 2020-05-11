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
    
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: BeerClassifier().model)
            let request = VNCoreMLRequest(model: model, completionHandler: {   [weak self] request, error in
                self?.processClassifications(for: request, error: error)
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
        openLibrary()
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
                self.createClassificationsRequest(image: imageTaken)
            }
        }
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension ViewController {
    func createClassificationsRequest(image: UIImage) {
        resultLabel.text = "Analyzing..."
        let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue))
        guard let ciImage = CIImage(image: image)
        else {
          fatalError("Unable to create \(CIImage.self) from \(image).")
        }
        DispatchQueue.global(qos: .userInitiated).async {
           let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation!)
           do {
            try handler.perform([self.classificationRequest])
           } catch {
            print("Failed to perform \n\(error.localizedDescription)")
           }
        }
    }
    
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results
            else {
              self.resultLabel.text = "Unable to analyze image.\n\(error!.localizedDescription)"
              return
            }
            let classifications = results as! [VNClassificationObservation]
            if classifications.isEmpty {
                self.resultLabel.text = "Nothing recognized."
            } else {
                let topClassifications = classifications.prefix(2)
                let descriptions = topClassifications.map { classification in
                    return String(format: "(%.2f) %@", classification.confidence, classification.identifier)
                }
                self.resultLabel.text = descriptions.joined(separator: " | ")
            }
        }
    }
}
