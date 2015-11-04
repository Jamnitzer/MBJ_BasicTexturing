//
//  Material.m
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
class Material
{
    var vertexFunction:MTLFunction! = nil
    var fragmentFunction:MTLFunction! = nil
    var diffuseTexture:MTLTexture! = nil

    init(vertexFunction:MTLFunction,
        fragmentFunction:MTLFunction,
        diffuseTexture:MTLTexture)
    {
        self.vertexFunction = vertexFunction;
        self.fragmentFunction = fragmentFunction;
        self.diffuseTexture = diffuseTexture;
    }
}
//------------------------------------------------------------------------------
