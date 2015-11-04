//
//  OBJGroup.m
//  BasicTexturing
//
//  Created by Warren Moore on 9/28/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//------------------------------------------------------------------------
//  converted to Swift by Jamnitzer (Jim Wrenholt)
//------------------------------------------------------------------------
import UIKit
import Metal

//------------------------------------------------------------------------------
class OBJGroup
{
    var name:String = "OBJGroup"
    var vertexData:NSData! = nil
    var indexData:NSData! = nil
    
    init(name:String)
    {
        self.name = name
    }
}
//------------------------------------------------------------------------------
