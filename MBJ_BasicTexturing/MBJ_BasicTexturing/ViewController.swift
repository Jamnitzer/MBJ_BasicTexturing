//
//  ViewController.mm
//  BasicTexturing
//
//  Created by Warren Moore on 9/22/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//------------------------------------------------------------------------
//  converted to Swift by Jamnitzer (Jim Wrenholt)
//------------------------------------------------------------------------
import UIKit
import Foundation
import simd
import Accelerate
import AudioToolbox

//------------------------------------------------------------------------------------
class ViewController: UIViewController
{
    let kVelocityScale:CGFloat = 0.01
    let kRotationDamping:CGFloat = 0.05
    
    let kMooSpinThreshold:CGFloat = 30
    let kMooDuration:CGFloat = 3
    
    var redrawTimer:CADisplayLink! = nil
    var renderer:Renderer! = nil
    var mesh:Mesh! = nil
    var material:Material! = nil
    var mooSound:SystemSoundID = 0
    var lastMooTime:NSTimeInterval = 0.0
    var angularVelocity = CGPointMake(0.0, 0.0)
    var angle = CGPointMake(0.0, 0.0)
    var lastFrameTime:NSTimeInterval = 0.0
    
    //------------------------------------------------------------------------------
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    //------------------------------------------------------------------------------
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.renderer = Renderer(view:view)
        loadModel()
    }
    //------------------------------------------------------------------------------
    override func viewDidAppear(animated:Bool)
    {
        super.viewDidAppear(animated)
        
        self.redrawTimer = CADisplayLink(target: self, selector: Selector("redrawTimerDidFire:"))
        redrawTimer.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: "gestureDidRecognize:")
        self.view.addGestureRecognizer(panGesture)
    }
    //------------------------------------------------------------------------------
    override func viewWillDisappear(animated:Bool)
    {
        super.viewWillDisappear(animated)
        redrawTimer.invalidate()
        redrawTimer = nil
    }
    //------------------------------------------------------------------------------
    func redrawTimerDidFire(sender:CADisplayLink)
    {
        redraw()
    }
    //------------------------------------------------------------------------------
    func gestureDidRecognize(gestureRecognizer: UIGestureRecognizer) -> Bool
    {
        if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer
        {
            let velocity:CGPoint = panGestureRecognizer.velocityInView(view)
            self.angularVelocity = CGPointMake(velocity.x * kVelocityScale,
                velocity.y * kVelocityScale);
        }
        return true
    }
    //------------------------------------------------------------------------------
    func loadModel()
    {
        //----------------------------------------------------------
        // Load geometry from OBJ file
        //----------------------------------------------------------
        let modelURL:NSURL? = NSBundle.mainBundle().URLForResource("spot", withExtension: "obj")
        if (modelURL == nil)
        {
            print("The model could not be located in the main bundle");
        }
        else
        {
            let model = OBJModel(fileURL:modelURL!, generateNormals:true)
            // print("model.groups = \(model.groups.count) ")
            let group:OBJGroup = model.groups[1]
            self.mesh = renderer.newMeshWithOBJGroup(group)
            self.material = renderer.newMaterialWithVertexFunctionNamed("vertex_main",
                fragmentFunctionName:"fragment_main",
                diffuseTextureName:"spot_texture")
        }
        //------------------------------------------------
        // Load sound effect
        //----------------------------------------------------------
        let mooURL = NSBundle.mainBundle().URLForResource("moo", withExtension: "aiff")
        if (mooURL == nil)
        {
            print("Could not find sound effect file in main bundle");
        }
        
        let result:OSStatus = AudioServicesCreateSystemSoundID(mooURL!, &mooSound )
        if (result != noErr)
        {
            print("Error when loading sound effect. Error code %d", result);
        }
    }
    //------------------------------------------------------------------------------
    func updateMotion()
    {
        //------------------------------------------------
        // Compute duration of previous frame
        //------------------------------------------------
        let frameTime:CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        let deltaTime = frameTime - lastFrameTime
        lastFrameTime = frameTime
        
        if (deltaTime > 0)
        {
            //----------------------------------------------------------
            // Update the rotation angles according to the
            // current velocity and time step
            //----------------------------------------------------------
            angle = CGPointMake(angle.x + angularVelocity.x * CGFloat(deltaTime),
                angle.y + angularVelocity.y * CGFloat(deltaTime));
            
            //----------------------------------------------------------
            // Apply damping by removing some proportion of
            // the angular velocity each frame
            //----------------------------------------------------------
            angularVelocity = CGPointMake(angularVelocity.x * (1 - kRotationDamping),
                angularVelocity.y * (1 - kRotationDamping));
            
            let spinSpeed:CGFloat = hypot(angularVelocity.x, angularVelocity.y);
            
            //----------------------------------------------------------
            // If we're spinning fast and haven't mooed in a while,
            // trigger the moo sound effect
            //----------------------------------------------------------
            if ((spinSpeed > kMooSpinThreshold) &&
                (frameTime > (lastMooTime + NSTimeInterval(kMooDuration))))
            {
                AudioServicesPlaySystemSound(mooSound);
                lastMooTime = frameTime;
            }
            //----------------------------------------------------------
        }
    }
    //------------------------------------------------------------------------------
    func updateTransformations()
    {
        //------------------------------------------------
        // Build the perspective projection matrix
        //------------------------------------------------
        let size:CGSize = view.bounds.size
        let aspectRatio:Float = Float(size.width) / Float(size.height)
        let verticalFOV:Float = (aspectRatio > 1.0) ? 45.0 : 90.0
        let near:Float = 0.1
        let far:Float = 100.0
        
        let projectionMatrix:float4x4 = PerspectiveProjection(aspectRatio,
            fovy: verticalFOV * (Float(M_PI) / 180.0), near: near, far: far)
        
        //------------------------------------------------
        // Build the model view matrix by rotating
        // and then translating "out" of the screen
        //------------------------------------------------
        let X:float3 = float3(1.0, 0.0, 0.0)
        let Y:float3 = float3(0.0, 1.0, 0.0)
        
        let rotX:float4x4 = Rotation(X, angle: Float(-angle.y))
        let rotY:float4x4 = Rotation(Y, angle: Float(-angle.x))
        
        var modelViewMatrix = float4x4(1.0) // identity
        modelViewMatrix = modelViewMatrix * rotX
        modelViewMatrix = modelViewMatrix * rotY
        modelViewMatrix[3].z = -1.5;
        
        self.renderer.modelViewMatrix = modelViewMatrix;
        self.renderer.modelViewProjectionMatrix = projectionMatrix * modelViewMatrix;
    }
    //------------------------------------------------------------------------------
    func redraw()
    {
        updateMotion()
        updateTransformations()
        
        renderer.startFrame()
        renderer.drawMesh(mesh, material:material)
        renderer.endFrame()
    }
    //------------------------------------------------------------------------------
}

