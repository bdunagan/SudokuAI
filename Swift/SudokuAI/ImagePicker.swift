
//
//  ImagePicker.swift
//  SudokuAI
//
//  Created by Brian Dunagan.
//
// Parts taken from https://github.com/appcoda/ImagePickerSwiftUI

import UIKit
import SwiftUI
import Vision

struct ImagePicker: UIViewControllerRepresentable {
	@Environment(\.managedObjectContext) private var viewContext

	var sourceType: UIImagePickerController.SourceType = .camera
	@Binding var selectedImage: UIImage
	@Environment(\.presentationMode) private var presentationMode

    @State var results: [VNRecognizedTextObservation]?
    @State var resultsDetect: [VNTextObservation]?
	@State var requestHandler: VNImageRequestHandler?
    @State var textRecognitionRequest: VNRecognizeTextRequest!
    @State var textDetectRequest: VNDetectTextRectanglesRequest!

	func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
 
		let imagePicker = UIImagePickerController()
		imagePicker.allowsEditing = false
		imagePicker.sourceType = sourceType
		imagePicker.delegate = context.coordinator

		return imagePicker
	}
 
	func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
		// Nothing to do.
	}

	func makeCoordinator() -> Coordinator {
			Coordinator(self)
		}
		
	
	final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
	 
		var parent: ImagePicker

		init(_ parent: ImagePicker) {
			self.parent = parent
		}
	 
		func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
	 
			if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
				parent.selectedImage = image
			}
			
			parent.performOCRRequest()

			parent.presentationMode.wrappedValue.dismiss()
		}

	}

	func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
		let context = CIContext(options: nil)
		if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
			return cgImage
		}
		return nil
	}
	
	func performOCRRequest() {
        textRecognitionRequest = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
		textRecognitionRequest.recognitionLevel = .accurate
		textRecognitionRequest.usesLanguageCorrection = true
        textRecognitionRequest.recognitionLanguages = ["en-US"]
		textRecognitionRequest.usesCPUOnly = false
		textRecognitionRequest.revision = VNRecognizeTextRequestRevision1
		requestHandler = VNImageRequestHandler(cgImage: convertCIImageToCGImage(inputImage: CIImage(image: selectedImage)!)!)

		// Reset the previous request.
		textRecognitionRequest.cancel()
		do {
			try self.requestHandler?.perform([self.textRecognitionRequest])
		} catch _ {}
	}
	
	func recognizeTextHandler(request: VNRequest, error: Error?) {
        self.results = self.textRecognitionRequest.results

        // Calculate topLeft and bottomRight of source image's grid based on recognized characters.
		var grid_start: CGPoint = CGPoint.init(x: 1.0, y: 1.0)
		var grid_end: CGPoint = CGPoint.init(x: 0.0, y: 0.0)
		if let results = self.results {
			for observation in results {
				// Find topLeft/bottomRight of grid.
				if observation.topLeft.x < grid_start.x {
					grid_start.x = observation.topLeft.x
				}
				if observation.topLeft.y < grid_start.y {
					grid_start.y = observation.topLeft.y
				}
				if observation.bottomRight.x > grid_end.x {
					grid_end.x = observation.bottomRight.x
				}
				if observation.bottomRight.y > grid_end.y {
					grid_end.y = observation.bottomRight.y
				}
			}
		}

        // Create item.
        let newItem = Item(context: viewContext)
        newItem.timestamp = Date()
        let squares = newItem.squares

		// grid_coordinates: [A1 => (topLeft, bottomRight)] normalized to 0 -> 8 each direction
		var grid_coordinates: [String:(CGPoint, CGPoint)] = [:]
		let gridRows = stride(from: 0, to: squares.count, by: 9).map {
			Array(squares[$0..<min($0 + 9, squares.count)])
		}
		for (rowIndex,gridRow) in gridRows.enumerated() {
			for (columnIndex,square) in gridRow.enumerated() {
				grid_coordinates[square] = (CGPoint.init(x: columnIndex, y: rowIndex), CGPoint.init(x: columnIndex + 1, y: rowIndex + 1))
			}
		}

		// Populate values.
		var grid_values: [String:String] = [:]
		
        if let observations = self.results {
            for observation in observations {
                let candidate: VNRecognizedText = observation.topCandidates(1)[0]
                for (characterIndex,character) in candidate.string.enumerated() {
                    // print("VN: \(candidate.string): \(character) (\(characterIndex))")
                    let range = candidate.string.index(candidate.string.startIndex, offsetBy: characterIndex)
                    let range_plus_1 = candidate.string.index(candidate.string.startIndex, offsetBy: characterIndex+1)
                    do {
                        let box = try candidate.boundingBox(for: range..<range_plus_1)
                        let midPoint = CGPoint.init(x: 9 * (box!.topLeft.x + box!.topRight.x) / 2, y: 9 - 9 * (box!.topRight.y + box!.bottomRight.y) / 2)
                        grid_coordinates.forEach { square, coordinates in
                            let topLeft: CGPoint = coordinates.0
                            let bottomRight: CGPoint = coordinates.1
                            if (topLeft.x < midPoint.x &&
                                topLeft.y < midPoint.y &&
                                bottomRight.x > midPoint.x &&
                                bottomRight.y > midPoint.y) {
                                grid_values[square] = character.isNumber ? String(character) : "1" // Assume "1" if it's not a number.
                                print("\(square): \(grid_values[square]!)")
                            }
                        }
                    } catch _ {}
                }

            }
        }

        // Save the item.
		var grid_string = ""
		squares.forEach { square in
			grid_string += grid_values[square] ?? "."
		}
		newItem.grid = grid_string
		newItem.image = selectedImage.jpegData(compressionQuality: 1.0)
        newItem.name = "Untitled"
        newItem.currentGrid = newItem.grid
        newItem.solveGrid()

        do {
			try viewContext.save()
		} catch {
			let nsError = error as NSError
			fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
		}
	}
}

