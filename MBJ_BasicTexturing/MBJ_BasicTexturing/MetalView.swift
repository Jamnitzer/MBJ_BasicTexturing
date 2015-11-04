//
//  MetalView.m
//  BasicTexturing
//
//  Created by Warren Moore on 9/22/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//------------------------------------------------------------------------
//  converted to Swift by Jamnitzer (Jim Wrenholt)
//------------------------------------------------------------------------
import UIKit
import Metal

//------------------------------------------------------------------------------
class MetalView : UIView
{
    var metalLayer:CAMetalLayer! = nil
    var device:MTLDevice! = nil
    var did_init:Bool = false
    
    //-------------------------------------------------------------------------
    override class func layerClass() -> AnyClass
    {
        return CAMetalLayer.self
    }
    //-------------------------------------------------------------------------
    override init(frame: CGRect) // default initializer
    {
        super.init(frame: frame)
        self.initCommon()
    }
    //-------------------------------------------------------------------------
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        self.initCommon()
    }
    //-------------------------------------------------------------------------
    func initCommon()
    {
        metalLayer = self.layer as? CAMetalLayer
        if (metalLayer == nil)
        {
            print("NO metalLayer HERE")
        }
        
//        let drawableSize:CGSize = metalLayer.drawableSize
//        print("drawableSize.width = \(drawableSize.width)")
//        print("drawableSize.height = \(drawableSize.height)")
        
       device = MTLCreateSystemDefaultDevice()
        metalLayer?.device = device
        metalLayer?.pixelFormat = .BGRA8Unorm
        did_init = true
    }
    //-------------------------------------------------------------------------
    override var frame: CGRect
    {
        didSet
        {
            //------------------------------------------------
            // During the first layout pass, we will not be
            // in a view hierarchy, so we guess our scale
            //------------------------------------------------
            var scale:CGFloat = UIScreen.mainScreen().scale
            
            //------------------------------------------------
            // If we've moved to a window by the time our frame
            // is being set, we can take its scale as our own
            //------------------------------------------------
            if let wind = self.window
            {
                scale = wind.screen.scale
            }
            var drawableSize:CGSize = self.bounds.size

            //------------------------------------------------
            // Since drawable size is in pixels, we need to multiply
            // by the scale to move from points to pixels
            //------------------------------------------------
            drawableSize.width *= scale
            drawableSize.height *= scale
            
            if (did_init)
            {
                self.metalLayer.drawableSize = drawableSize
            }
        }
    }
    //-------------------------------------------------------------------------
}
//------------------------------------------------------------------------------
