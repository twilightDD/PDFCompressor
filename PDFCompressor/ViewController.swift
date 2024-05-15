//
//  ViewController.swift
//  PDFCompressor
//
//  Created by Peter Hauke on 10.05.24.
//  Copyright © 2020 2sox. All rights reserved.
//

import Cocoa


class ViewController: NSViewController {

    //MARK: - Lets and vars
    private var inputURL: URL?
    private var outputURL: URL?
    private var mode: PDFCompressor.Mode = .serialEncode
    
    private var compressionValue: Double = 0.7 {
        didSet {
            compressionValueTextField.stringValue = String(format: "%3.0f %%", compressionValue * 100)
        }
    }
    private var scaleValue: Double = 0.9 {
        didSet {
            scaleValueTextField.stringValue = String(format: "%3.0f %%", scaleValue * 100)
        }
    }
    
    //MARK: - IBOutlets
    
    @IBOutlet weak var selectPDFFileButton: NSButton!
    @IBOutlet weak var fileURLLabel: NSTextField!
    
    @IBOutlet weak var compressionSlider: NSSlider!
    @IBOutlet weak var compressionValueTextField: NSTextField!
    @IBOutlet weak var scaleSlider: NSSlider!
    @IBOutlet weak var scaleValueTextField: NSTextField!
    
    @IBOutlet weak var logTextView: NSTextView!
    
    
    //MARK: - Init&Co
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        compressionSlider.minValue = 0.1
        compressionSlider.maxValue = 1.0
        compressionSlider.doubleValue = compressionValue
        compressionValueTextField.stringValue = String(format: "%3.0f %%", compressionValue * 100)
        
        scaleSlider.minValue = 0.1
        scaleSlider.maxValue = 1.0
        scaleSlider.doubleValue = scaleValue
        scaleValueTextField.stringValue = String(format: "%3.0f %%", scaleValue * 100)
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    
    //MARK: - Action Methods
    @IBAction func compressionSliderAction(_ sender: NSSlider) {
        compressionValue = sender.doubleValue
    }
    
    
    @IBAction func scaleSliderAction(_ sender: NSSlider) {
        scaleValue = sender.doubleValue
    }
    
    
    @IBAction func selectPDFFileButtonAction(_ sender: NSButton) {
        let dialog = NSOpenPanel()
        
        dialog.title                   = "Choose a .pdf file"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        dialog.canChooseDirectories    = true
        dialog.allowsMultipleSelection = false
        dialog.allowedContentTypes     = [.pdf]
        
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            if let url = dialog.url {
                inputURL = url
                fileURLLabel.stringValue = url.path
                askForSavingDirectory()
            }
            
        } else {
            fileURLLabel.stringValue = "Fehler"
            return
        }
    }
    
    @IBAction func dispatchQueueCompressButtonAction(_ sender: NSButton) {
        startCompression(mode: .dispatchQueueEncode)
    }
    
    @IBAction func parallelCompressButtonAction(_ sender: NSButton) {
        startCompression(mode: .parallelEncode)
    }

    @IBAction func serialCompressButtonAction(_ sender: NSButton) {
        startCompression(mode: .serialEncode)
    }
    
    
    private func startCompression(mode: PDFCompressor.Mode) {
        guard let inputURL else {
            return }
        guard let outputURL else {
            return
        }
//        let inputDirectoryURL = inputURL.deletingLastPathComponent()
//        let pathExtension = inputURL.pathExtension
//        let fileName = inputURL.deletingPathExtension().lastPathComponent
//        let outURL = inputDirectoryURL
//            .appending(component: "\(fileName)_compressed")
//            .appendingPathExtension(pathExtension)
//        outputURL = outURL
        let pdfCompressor = PDFCompressor()
        do {
            try pdfCompressor.compress(inputURL, out: outputURL,
                                       compression: compressionValue, scale: scaleValue,
                                       mode: mode, delegate: self)
        }
        catch let compressError {
            print("\(compressError)")
        }
        
    }
    
    func askForSavingDirectory() {
        guard let inputURL else {
            return }
        let inputDirectoryURL = inputURL.deletingLastPathComponent()
        let pathExtension = inputURL.pathExtension
        let fileName = inputURL.deletingPathExtension().lastPathComponent
        let outURL = inputDirectoryURL
            .appending(component: "\(fileName)_compressed")
            .appendingPathExtension(pathExtension)
        outputURL = outURL
        
        let dialog = NSSavePanel()
        dialog.title                   = "Choose a destination file"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        dialog.allowedContentTypes     = [.pdf]
        dialog.directoryURL = inputDirectoryURL
        
        
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            if let url = dialog.url {
                outputURL = url
            }
            
        } else {
            fileURLLabel.stringValue = "Fehler"
            return
        }
    }
}

extension ViewController: SOXTimingDelegate {
    
    func addToLog(_ logline: String) {
        
        logTextView.string = logTextView.string.appending("\n\(logline)")
    }
}
