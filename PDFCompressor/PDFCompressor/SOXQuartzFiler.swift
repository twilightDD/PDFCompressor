//
//  SOXQuartzFiler.swift
//  PDFCompressor
//
//  Created by Peter Hauke on 15.05.24.
//

import Foundation
import Quartz

struct SOXQuartzFiler {
    
    static func quartzFilter(compression: Double, scale: Double)
    -> QuartzFilter? {
        let properties: [AnyHashable : Any] = [
            "Domains" : [
                "Applications" : true
            ],
            "FilterData" : [
                "ColorSettings" : [
                    "ImageSettings" : [
                        "Compression Quality" : compression * -1,
                        "ImageCompression" : "ImageJPEGCompress",
                        "ImageScaleSettings" : [
                            "ImageScaleFactor" : scale
                        ]
                    ]
                ]
            ],
            "FilterType" : 1,
            "Name" : "Compress PDF"
            
        ]
        let quartzFilter = QuartzFilter(properties: properties)
        return quartzFilter
    }
    
}
