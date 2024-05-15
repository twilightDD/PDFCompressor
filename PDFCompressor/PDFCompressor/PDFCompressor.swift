//
//  PDFCompressor.swift
//  compress-pdf
//
//  Created by Maxim Puchkov on 2020-09-24.
//  Copyright © 2020 Maxim Puchkov. All rights reserved.
//  Changed by Peter Hauke on 10.05.24.
//

import Foundation
import Quartz

/**
 PDFCompressor reduces size of Portable Document Format (PDF) files by
 applying a JPEG compression quartz filter to a copy of the input file.
 */
public class PDFCompressor {
    
    public enum Mode {
        case dispatchQueueEncode
        case parallelEncode
        case serialEncode
    }
    
    //MARK: - Lets and Vars
    /// File name of the default filter (currently the only filter).
    public static let kDefaultFilterName: String = "Compress PDF"
    
    /// Search framework resources for quartz filter specified by its name.
    ///
    /// - Parameter filterName: name of a bundled quartz filter.
    public static func getFilterURL(name filterName: String)
    -> URL? {
        let ext = "qfilter"
        let filterURL = Bundle.main.url(forResource: filterName, withExtension: ext)
        return filterURL
    }
    
    /// Quartz filter will be applied to data between 'stream' and 'endstream' PDF keywords.
    private let quartz_filter: QuartzFilter
    
    /// Quartz filter's localized display name.
    public var filterName: String {
        get { return self.quartz_filter.localizedName() }
    }
    
    
    
    //MARK: - Init&Co
    
    /// Create a PDF compressor with default filter.
    public convenience init() {
        let filterURL = Self.getFilterURL(name: Self.kDefaultFilterName)!
        self.init(url: filterURL)
    }
    
    
    /// Create a PDFCompressor with quartz filter specified by its name.
    /// If filter name is not provided, the default filter will be used.
    ///
    /// - Parameter filterName: name of quartz filter to be used for compression (optional).
    /// - Throws: `PDFCompressionError.QuartzFilterNotFoundError`
    ///            if quartz  filter named `filterName` is not found.
    public convenience init!(name filterName: String = kDefaultFilterName) throws {
        guard let filterURL = Self.getFilterURL(name: filterName) else {
            throw PDFCompressionError.QuartzFilterNotFoundError(filterName: filterName)
        }
        self.init(url: filterURL)
    }
    
    
    /// Create a PDFCompressor with quartz filter specified by its URL.
    ///
    /// - Parameter filterURL: location of quartz filter to be used for compression.
    private init(url filterURL: URL) {
        self.quartz_filter = QuartzFilter(url: filterURL)
    }
    
    
    //MARK: - Public methods
    /// Apply compression filter to PDF document.
    ///
    /// - Parameters:
    ///   - inPath:  path to the input PDF file.
    ///   - outPath: path where output PDF file will be written to.
    /// - Throws: `PDFCompressionError.PDFFileNotFoundError`
    ///            if PDF file at `inPath` is not found.
    /// - Returns: location of output document context.
    @discardableResult
    public func compress(_ inPath: String, out outPath: String,
                         compression: Double, scale: Double,
                         mode: Mode, delegate: SOXTimingDelegate) throws
    -> CFURL {
        let inURL = URL(fileURLWithPath: inPath)
        let outURL = URL(fileURLWithPath: outPath)
        
        return try self.compress(inURL, out: outURL,
                                 compression: compression, scale: scale,
                                 mode: mode, delegate: delegate)
    }
    
    
    /// Apply compression filter to PDF document.
    ///
    /// - Parameters:
    ///   - inURL:  location of the input PDF file.
    ///   - outURL: location where output PDF file will be written to.
    /// - Throws: `PDFCompressionError.PDFFileNotFoundError`
    ///            if PDF file at `inURL` is not found.
    /// - Returns: location of output document context.
    @discardableResult
    public func compress(_ inURL: URL, out outURL: URL,
                         compression: Double, scale: Double,
                         mode: Mode, delegate: SOXTimingDelegate) throws
    -> CFURL {
        // Make sure input PDF file at 'inURL' is valid
        guard let inFile = PDFDocument(url: inURL) else {
            throw PDFCompressionError.PDFFileNotFoundError(fileURL: inURL.absoluteURL)
        }
        
        // Get original input PDF document at 'inURL'
        let inPDF: CGPDFDocument = inFile.documentRef!
        
        switch mode {
            case .dispatchQueueEncode:
                try dispatchQueueEncode(inPDF: inPDF, outputURL: outURL,
                                        compression: compression, scale: scale,
                                        delegate: delegate)
            case .parallelEncode:
                try parallelEncode(inPDF: inPDF, outputURL: outURL,
                                   compression: compression, scale: scale,
                                   delegate: delegate)
            case .serialEncode:
                try serialEncode(inPDF: inPDF, outputURL: outURL,
                                 compression: compression, scale: scale,
                                 delegate: delegate)
        }
        
        return (outURL as CFURL)
    }
    
    
    //MARK: - Private Compression Methods
    private func dispatchQueueEncode(inPDF: CGPDFDocument, outputURL: URL,
                                     compression: Double, scale: Double,
                                     delegate: SOXTimingDelegate) throws {
        let tempDir = FileManager().temporaryDirectory
        var tempURLs: [URL?] = [URL?](repeatElement(nil,
                                                    count: inPDF.numberOfPages + 1))
        
        let concurrentQueue = DispatchQueue(label: "swiftlee.concurrent.queue", attributes: .concurrent)
        
        let totalTimer = SOXTiming(title: "Total parallel time \(inPDF.numberOfPages) pages in")
        
        let compressionTimer = SOXTiming(title: "compress time \(inPDF.numberOfPages) pages in")
        
        for index in 1...inPDF.numberOfPages {
            let pageIndex = index
            concurrentQueue.async {
                // Create an empty temp PDF document
                let tempURL = tempDir.appendingPathComponent("\(pageIndex)", conformingTo: .pdf)
                let outPDF = CGContext(tempURL as CFURL, mediaBox: nil, nil)
                guard let outPDF else {
                    fatalError() }
                guard let quartzFilter = SOXQuartzFiler.quartzFilter(compression: compression, scale: scale) else {
                    return }
                quartzFilter.apply(to: outPDF)  // All PDF pages drawn after the filter is applied will be compressed
                
                let timer = SOXTiming(title: "Encode and write temp page \(pageIndex)")
                
                // Get current page and its size (bounds) from input document
                let page: CGPDFPage = inPDF.page(at: pageIndex)!
                var pageMediaBox: CGRect = page.getBoxRect(.mediaBox)
                
                // Redraw current page in output document
                outPDF.beginPage(mediaBox: &pageMediaBox)
                outPDF.drawPDFPage(page)
                outPDF.endPage()
                outPDF.closePDF()
                
                tempURLs[pageIndex] = tempURL
                timer.stop()
                
            }
        }
        
        
        compressionTimer.stop(delegate: delegate)
        
        try concurrentQueue.sync(flags: .barrier) {
            // Assemble and write final PDF
            let outContext = CGContext(outputURL as CFURL, mediaBox: nil, nil)
            guard let outContext else {
                throw  NSError(domain: "cgcontext", code: 100) }
            let outPDF: CGContext = outContext
            
            let writeTimer = SOXTiming(title: "Wrinting")
            for index in 1...inPDF.numberOfPages {
                let timer = SOXTiming(title: "assemble final pdf: temp page \(index)")
                let tempURL: URL = tempURLs[index]!
                guard let inTempFile = PDFDocument(url: tempURL) else {
                    throw PDFCompressionError.PDFFileNotFoundError(fileURL: tempURL.absoluteURL)
                }
                
                // Get original input PDF document at 'inURL'
                let inTempPDF: CGPDFDocument = inTempFile.documentRef!
                let page: CGPDFPage = inTempPDF.page(at: 1)!
                var pageMediaBox: CGRect = page.getBoxRect(.mediaBox)
                
                // Redraw current page in output document
                outPDF.beginPage(mediaBox: &pageMediaBox)
                outPDF.drawPDFPage(page)
                outPDF.endPage()
                
                
                timer.stop(delegate: delegate)
            }
            writeTimer.stop(delegate: delegate)
            outPDF.closePDF()
            totalTimer.stop(delegate: delegate)
        }
    }
    
    
    private func parallelEncode(inPDF: CGPDFDocument, outputURL: URL,
                                compression: Double, scale: Double,
                                delegate: SOXTimingDelegate) throws {
        let tempDir = FileManager().temporaryDirectory
        var tempURLs: [URL?] = [URL?](repeatElement(nil,
                                                    count: inPDF.numberOfPages + 1))
        
        let totalTimer = SOXTiming(title: "Total parallel time \(inPDF.numberOfPages) pages in")
        
        let compressionTimer = SOXTiming(title: "compress time \(inPDF.numberOfPages) pages in")
        
        
        // Parallel compression to single page temp files
        tempURLs.withUnsafeMutableBufferPointer { tempURLsBuffer in
            DispatchQueue.concurrentPerform(iterations: inPDF.numberOfPages,
                                            execute: { index in
                let pageIndex = index + 1
                
                // Create an empty temp PDF document
                let tempURL = tempDir.appendingPathComponent("\(pageIndex)", conformingTo: .pdf)
                let outPDF = CGContext(tempURL as CFURL, mediaBox: nil, nil)
                guard let outPDF else {
                    fatalError() }
                guard let quartzFilter = SOXQuartzFiler.quartzFilter(compression: compression, scale: scale) else {
                    return }
                quartzFilter.apply(to: outPDF)  // All PDF pages drawn after the filter is applied will be compressed
                
                let timer = SOXTiming(title: "Encode and write temp page \(pageIndex)")
                
                // Get current page and its size (bounds) from input document
                let page: CGPDFPage = inPDF.page(at: pageIndex)!
                var pageMediaBox: CGRect = page.getBoxRect(.mediaBox)
                
                // Redraw current page in output document
                outPDF.beginPage(mediaBox: &pageMediaBox)
                outPDF.drawPDFPage(page)
                outPDF.endPage()
                outPDF.closePDF()
                
                tempURLsBuffer[pageIndex] = tempURL
                DispatchQueue.main.async {
                    timer.stop()
                }
            })
        }
        
        compressionTimer.stop(delegate: delegate)
        
        
        // Assemble and write final PDF
        let outContext = CGContext(outputURL as CFURL, mediaBox: nil, nil)
        guard let outContext else {
            throw  NSError(domain: "cgcontext", code: 100) }
        let outPDF: CGContext = outContext
        
        let writeTimer = SOXTiming(title: "Wrinting")
        for index in 1...inPDF.numberOfPages {
            let timer = SOXTiming(title: "assemble final pdf: temp page \(index)")
            let tempURL: URL = tempURLs[index]!
            guard let inTempFile = PDFDocument(url: tempURL) else {
                throw PDFCompressionError.PDFFileNotFoundError(fileURL: tempURL.absoluteURL)
            }
            
            // Get original input PDF document at 'inURL'
            let inTempPDF: CGPDFDocument = inTempFile.documentRef!
            let page: CGPDFPage = inTempPDF.page(at: 1)!
            var pageMediaBox: CGRect = page.getBoxRect(.mediaBox)
            
            // Redraw current page in output document
            outPDF.beginPage(mediaBox: &pageMediaBox)
            outPDF.drawPDFPage(page)
            outPDF.endPage()
            
            
            timer.stop(delegate: delegate)
        }
        writeTimer.stop(delegate: delegate)
        outPDF.closePDF()
        totalTimer.stop(delegate: delegate)
        
    }
    
    
    private func serialEncode(inPDF: CGPDFDocument, outputURL: URL,
                              compression: Double, scale: Double,
                              delegate: SOXTimingDelegate) throws {
        
        // Create outputPDF with compression filter.
        let outPDF = CGContext(outputURL as CFURL, mediaBox: nil, nil)
        guard let outPDF else {
            throw  NSError(domain: "cgcontext", code: 100) }
        guard let quartzFilter = SOXQuartzFiler.quartzFilter(compression: compression, scale: scale) else {
            return }
        quartzFilter.apply(to: outPDF)  // All PDF pages drawn after the filter is applied will be compressed
        
        let totalTimer = SOXTiming(title: "Total serial time \(inPDF.numberOfPages) pages in")
        
        // Copy every page to new output document
        for index in 1...inPDF.numberOfPages {
            let pageTimer = SOXTiming(title: "Encode and write page \(index)")
            
            // Get current page and its size (bounds) from input document
            let page: CGPDFPage = inPDF.page(at: index)!
            var pageMediaBox: CGRect = page.getBoxRect(.mediaBox)
            
            // Redraw current page in output document
            outPDF.beginPage(mediaBox: &pageMediaBox)
            outPDF.drawPDFPage(page)
            outPDF.endPage()
            
            delegate.addToLog(pageTimer.stop())
        }
        
        outPDF.closePDF()
        
        totalTimer.stop(delegate: delegate)
    }
    
}
