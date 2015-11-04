//
//  Mesh.m
//  BasicTexturing
//
//  Created by Warren Moore on 9/27/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//------------------------------------------------------------------------
//  converted to Swift by Jamnitzer (Jim Wrenholt)
//------------------------------------------------------------------------
import UIKit
import Metal

//------------------------------------------------------------------------------
class Mesh
{
    var vertexBuffer:MTLBuffer! = nil
    var indexBuffer:MTLBuffer! = nil
    
    init(vertexBuffer:MTLBuffer, indexBuffer:MTLBuffer)
    {
        self.vertexBuffer = vertexBuffer
        self.indexBuffer = indexBuffer
    }
}
//------------------------------------------------------------------------------
