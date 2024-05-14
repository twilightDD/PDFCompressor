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
    
    //MARK: - IBOutlets
    
    @IBOutlet weak var selectPDFFileButton: NSButton!
    @IBOutlet weak var fileURLLabel: NSTextField!
    @IBOutlet weak var logTextView: NSTextView!
    @IBOutlet weak var compressButton: NSButton!
    
    
    //MARK: - Init&Co
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    
    //MARK: - Action Methods
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
    @IBAction func serialCompressButtonAction(_ sender: NSButton) {
        startCompression(mode: .serialEncode)
    }
    
    @IBAction func parallelCompressButtonAction(_ sender: NSButton) {
        startCompression(mode: .parallelEncode)
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
            try pdfCompressor.compress(inputURL, out: outputURL, mode: mode, delegate: self)
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
        dialog.title                   = "Choose a directory"
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
