//
//  Renderer.m
//  BasicTexturing
//
//  Created by Warren Moore on 9/25/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//------------------------------------------------------------------------
//  converted to Swift by Jamnitzer (Jim Wrenholt)
//------------------------------------------------------------------------
import UIKit
import Metal
import simd
import Accelerate

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
class Renderer
{
    var view:UIView! = nil
    var layer:CAMetalLayer! = nil
    var device:MTLDevice! = nil
    var library:MTLLibrary! = nil
    var pipeline:MTLRenderPipelineState! = nil
    var commandQueue:MTLCommandQueue! = nil
    var pipelineDirty:Bool = false
    var uniformBuffer:MTLBuffer! = nil
    var depthTexture:MTLTexture! = nil
    var sampler:MTLSamplerState! = nil
    var currentRenderPass:MTLRenderPassDescriptor! = nil
    var currentDrawable:CAMetalDrawable! = nil
    
    var clearColor = UIColor(white: 0.95, alpha: 1.0)
    
    var modelViewProjectionMatrix:float4x4 = float4x4(1.0)
    var modelViewMatrix:float4x4 = float4x4(1.0)
    var normalMatrix:float4x4 = float4x4(1.0)
    //------------------------------------------------------------------------------
    init(view:UIView)
    {
        self.view = view
        if let metal_layer = view.layer as? CAMetalLayer
        {
            self.layer = metal_layer
        }
        else
        {
            print("Layer type of view used for rendering must be CAMetalLayer")
            assert(false)
        }
        self.clearColor = UIColor(white: 0.95, alpha: 1.0)
        self.pipelineDirty = true
        self.device = MTLCreateSystemDefaultDevice()
        
        initializeDeviceDependentObjects()
    }
    //------------------------------------------------------------------------------
    func initializeDeviceDependentObjects()
    {
        self.library =  self.device!.newDefaultLibrary()
        commandQueue = device!.newCommandQueue()
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = MTLSamplerMinMagFilter.Nearest
        samplerDescriptor.magFilter = MTLSamplerMinMagFilter.Linear
        self.sampler = self.device!.newSamplerStateWithDescriptor(samplerDescriptor)
    }
    //------------------------------------------------------------------------------
    func configurePipelineWithMaterial(material:Material)
    {
        let pos_offset = 0
        let norm_offset = pos_offset + sizeof(float4)
        let tc_offset = norm_offset + sizeof(float3)

        let vertexDescriptor = MTLVertexDescriptor()
        
        vertexDescriptor.attributes[0].format = MTLVertexFormat.Float4
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = pos_offset // offsetof(Vertex, position)
        
        vertexDescriptor.attributes[1].format = MTLVertexFormat.Float3
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = norm_offset // offsetof(Vertex, normal)
        
        vertexDescriptor.attributes[2].format = MTLVertexFormat.Float2
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.attributes[2].offset = tc_offset // offsetof(Vertex, texCoords)
        
        vertexDescriptor.layouts[0].stride = sizeof(Vertex)
        vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.PerVertex
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = material.vertexFunction
        pipelineDescriptor.fragmentFunction = material.fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
       
        pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.BGRA8Unorm
        
        pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormat.Depth32Float
        
        do {
            self.pipeline = try
                device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
        }
        catch let pipelineError as NSError
        {
            self.pipeline = nil
            print("Error occurred when creating render pipeline state \(pipelineError)")
            assert(false)
        }
    }
    //------------------------------------------------------------------------------
    func textureForImage(image:UIImage) -> MTLTexture?
    {
        let imageRef = image.CGImage
        
        // Create a suitable bitmap context for extracting the bits of the image
        let width = CGImageGetWidth(imageRef)
        let height = CGImageGetHeight(imageRef)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let rawData = calloc(height * width * 4, Int(sizeof(UInt8)))
        
        let bytesPerPixel: Int = 4
        let bytesPerRow: Int = bytesPerPixel * width
        let bitsPerComponent: Int = 8
        
        let options = CGImageAlphaInfo.PremultipliedLast.rawValue |
            CGBitmapInfo.ByteOrder32Big.rawValue
        
        let context = CGBitmapContextCreate(rawData, width, height,
            bitsPerComponent, bytesPerRow, colorSpace, options)
        // CGColorSpaceRelease(colorSpace)
        
        // Flip the context so the positive Y axis points down
        CGContextTranslateCTM(context, 0.0, CGFloat(height));
        CGContextScaleCTM(context, 1.0, -1.0);
        
        CGContextDrawImage(context, CGRectMake(0, 0,
            CGFloat(width), CGFloat(height)), imageRef)
        // CGContextRelease(context)
       
        let textureDescriptor =
        MTLTextureDescriptor.texture2DDescriptorWithPixelFormat( .RGBA8Unorm,
            width: Int(width), height: Int(height),
            mipmapped: true)
        
        let texture = device.newTextureWithDescriptor(textureDescriptor)
        texture.label = "textureForImage"
        
        let region = MTLRegionMake2D(0, 0, Int(width), Int(height))
        texture.replaceRegion(region, mipmapLevel: 0,
            withBytes: rawData, bytesPerRow: Int(bytesPerRow))
       
        free(rawData)
        return texture
    }
    //------------------------------------------------------------------------------
    func newMaterialWithVertexFunctionNamed(
        vertexFunctionName:String,
        fragmentFunctionName:String,
        diffuseTextureName:String) -> Material?
    {
        //------------------------------------------------------------------------
        // Creates a new material with the specified pair of vertex/fragment
        // functions and the specified diffuse texture name.
        // The texture name must refer to a PNG resource
        // in the main bundle in order to be loaded successfully.
        //------------------------------------------------------------------------
        let vertexFunction = library!.newFunctionWithName(vertexFunctionName)
        if (vertexFunction == nil)
        {
            print("Could not load vertex function named \(vertexFunctionName) from default library")
            return nil
        }
        //------------------------------------------------------------------------
       let fragmentFunction = library!.newFunctionWithName(fragmentFunctionName)
        if (fragmentFunction == nil)
        {
            print("Could not load fragment function named \(fragmentFunctionName) from default library")
            return nil
        }
        //------------------------------------------------------------------------
        let diffuseTextureImage = UIImage(named: diffuseTextureName)
        if (diffuseTextureImage == nil)
        {
            print("Unable to find PNG image named \(diffuseTextureName) in main bundle")
            return nil
        }
        //------------------------------------------------------------------------
        let diffuseTexture = textureForImage(diffuseTextureImage!)
        if (diffuseTexture == nil)
        {
            print("Could not create a texture from an image")
        }
        //------------------------------------------------------------------------
        let material:Material = Material(   vertexFunction:vertexFunction!,
                                            fragmentFunction:fragmentFunction!,
                                            diffuseTexture:diffuseTexture!)
        return material
    }
    //------------------------------------------------------------------------------
    func newMeshWithOBJGroup(group:OBJGroup) -> Mesh
    {
        let vertexBuffer:MTLBuffer = device!.newBufferWithBytes(
                group.vertexData.bytes,
                length: group.vertexData.length,
                options: .CPUCacheModeDefaultCache)
        
        let indexBuffer:MTLBuffer = device!.newBufferWithBytes(
                group.indexData.bytes,
                length: group.indexData.length,
                options: .CPUCacheModeDefaultCache)

        let mesh:Mesh = Mesh(vertexBuffer:vertexBuffer, indexBuffer:indexBuffer)
        return mesh
    }
    //------------------------------------------------------------------------------
    func createDepthBuffer()
    {
        let drawableSize:CGSize = layer.drawableSize
        
        let depthTexDesc = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
            MTLPixelFormat.Depth32Float,
            width: Int(drawableSize.width),
            height: Int(drawableSize.height),
            mipmapped: false
        )
        self.depthTexture = device!.newTextureWithDescriptor(depthTexDesc)
    }
    //------------------------------------------------------------------------------
    func updateUniforms()
    {
        if (uniformBuffer == nil)
        {
            self.uniformBuffer = device!.newBufferWithLength(
                sizeof(Uniforms), options: .CPUCacheModeDefaultCache)
        }
    
        var uniforms = Uniforms()
            uniforms.modelViewMatrix = self.modelViewMatrix
            uniforms.modelViewProjectionMatrix = self.modelViewProjectionMatrix
        
        let upleft3x3:float3x3 = UpperLeft3x3(self.modelViewMatrix)
        let trans_upleft:float3x3 = upleft3x3.transpose
        let inv_m:float3x3 = trans_upleft.inverse
        uniforms.normalMatrix = inv_m
        
        let bufferPointer:UnsafeMutablePointer<Void>? = uniformBuffer.contents()
        memcpy(bufferPointer!,
            &uniforms,             // the data.
            sizeof(Uniforms))      // num of bytes
    }
    //------------------------------------------------------------------------------
    func startFrame()
    {
        let drawableSize:CGSize = layer.drawableSize
        
        if ( (self.depthTexture == nil) ||
            CGFloat(depthTexture.width) != drawableSize.width ||
            CGFloat(depthTexture.height) != drawableSize.height)
        {
            createDepthBuffer()
        }
        
        let drawable:CAMetalDrawable? = self.layer.nextDrawable()
        if (drawable == nil)
        {
            print("Could not retrieve drawable from Metal layer")
            assert(false)
        }

        var r:CGFloat = 0.0
        var g:CGFloat = 0.0
        var b:CGFloat = 0.0
        var a:CGFloat = 0.0
        clearColor.getRed(&r, green:&g, blue:&b, alpha:&a)
        
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = drawable!.texture
        renderPass.colorAttachments[0].loadAction = MTLLoadAction.Clear
        renderPass.colorAttachments[0].storeAction = MTLStoreAction.Store
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(
                        Double(r), Double(g), Double(b), Double(a))
        
        renderPass.depthAttachment.texture = self.depthTexture
        renderPass.depthAttachment.loadAction = MTLLoadAction.Clear
        renderPass.depthAttachment.storeAction = MTLStoreAction.Store
        renderPass.depthAttachment.clearDepth = 1
        
        self.currentDrawable = drawable
        self.currentRenderPass = renderPass
    }
    //------------------------------------------------------------------------------
    func drawMesh(mesh:Mesh, material:Material)
    {
        configurePipelineWithMaterial(material)
        updateUniforms()
        
        let commandBuffer:MTLCommandBuffer = commandQueue.commandBuffer()
        
        let commandEncoder:MTLRenderCommandEncoder =
        commandBuffer.renderCommandEncoderWithDescriptor(currentRenderPass)
        
        commandEncoder.setVertexBuffer( mesh.vertexBuffer, offset: 0, atIndex: 0)
        commandEncoder.setVertexBuffer( self.uniformBuffer, offset: 0, atIndex: 1)
        commandEncoder.setFragmentBuffer( self.uniformBuffer, offset: 0, atIndex: 0)
        commandEncoder.setFragmentTexture(material.diffuseTexture, atIndex: 0)
        commandEncoder.setFragmentSamplerState(self.sampler, atIndex: 0)
        commandEncoder.setRenderPipelineState(self.pipeline)
        commandEncoder.setCullMode( MTLCullMode.Back)
        commandEncoder.setFrontFacingWinding(MTLWinding.CounterClockwise)
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = MTLCompareFunction.Less
        depthStencilDescriptor.depthWriteEnabled = true
        let depthStencilState = device!.newDepthStencilStateWithDescriptor(depthStencilDescriptor)
        commandEncoder.setDepthStencilState( depthStencilState)
        
        commandEncoder.drawIndexedPrimitives(MTLPrimitiveType.Triangle,
            indexCount: mesh.indexBuffer.length / sizeof(UInt16),
            indexType: MTLIndexType.UInt16,
            indexBuffer: mesh.indexBuffer, indexBufferOffset: 0)
        
        commandEncoder.endEncoding()
        commandBuffer.commit()
    }
    //------------------------------------------------------------------------------
    func endFrame()
    {
        let commandBuffer:MTLCommandBuffer = commandQueue.commandBuffer()
        commandBuffer.presentDrawable(currentDrawable)
        commandBuffer.commit()
    }
    //------------------------------------------------------------------------------
}
//-----------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------

