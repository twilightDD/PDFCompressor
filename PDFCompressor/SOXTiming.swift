//
//  SOXTiming.swift
//  Landrix Handwerk Mobile
//
//  Created by Peter Hauke on 30.01.20.
//  Copyright © 2020 Landrix Software GmbH & Co. KG. All rights reserved.
//

import QuartzCore

/**
 Helper thing to determine run time.

```
 let timer = SOXTiming()
 // code to time
 timer.stop()

 => Passed time: 0.0006299579981714487 s


 let timer = SOXTiming.init(title: "Setup browser")
 // code to time
 timer.stop(enhancedDescription: "\(fetchedPictures.count) items (lazy load)")

 =>  Passed time: "Setup browser" (4 items (lazy load)) 0.0005942310017417185 s
 ```
 */
class SOXTiming {

    private var startTime = CACurrentMediaTime()
    private(set) var passedTime: CFTimeInterval?
    /// Returns time since start of timer.
    var meanTime: CFTimeInterval {
        let currentTime = CACurrentMediaTime()
        let passedTime = currentTime - startTime
        return passedTime
    }
    private(set) var title: String?

    convenience init(title: String? = nil) {
        self.init()
        self.title = title
    }

    func stop(enhancedDescription: String? = nil) {
        let endTime = CACurrentMediaTime()
        passedTime = endTime - startTime

        let finalText = "Passed time:" + (title != nil ? " '\(title!)'" : "") + (enhancedDescription != nil ? " (\(enhancedDescription!))" : "") + ": \(passedTime ?? -1) s"

        print(finalText)
    }

    
}
