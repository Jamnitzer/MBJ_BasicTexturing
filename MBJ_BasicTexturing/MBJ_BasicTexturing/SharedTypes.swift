//
//  SharedTypes.h
//  BasicTexturing
//
//  Created by Warren Moore on 9/25/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//------------------------------------------------------------------------
//  converted to Swift by Jamnitzer (Jim Wrenholt)
//------------------------------------------------------------------------
import Foundation
import simd
import Accelerate

struct Vertex
{
    var position:float4 = float4(0, 0, 0, 0)
    var normal:float3 = float3(0, 0, 0)
    var texCoords:float2 = float2(0, 0)
    var fill:float2 = float2(0, 0)
};

struct Uniforms
{
    var modelViewProjectionMatrix:float4x4 = float4x4(0)
    var modelViewMatrix:float4x4 = float4x4(0)
    var normalMatrix:float3x3 = float3x3(0)
};
