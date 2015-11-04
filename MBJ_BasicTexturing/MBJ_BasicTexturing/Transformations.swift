//
//  Transformations.mm
//  BasicTexturing
//
//  Created by Warren Moore on 9/27/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//------------------------------------------------------------------------
//  converted to Swift by Jamnitzer (Jim Wrenholt)
//------------------------------------------------------------------------
import Foundation
import simd
import Accelerate

//------------------------------------------------------------------------------
func Identity() -> float4x4
{
    let identity = float4x4(1.0)
    return identity
}
//------------------------------------------------------------------------------
func Rotation(axis:float3, angle:Float) -> float4x4
{
    let c:Float = cos(angle);
    let s:Float = sin(angle);
    
    var X = float4()
    X.x = axis.x * axis.x + (1.0 - axis.x * axis.x) * c;
    X.y = axis.x * axis.y * (1.0 - c) - axis.z * s;
    X.z = axis.x * axis.z * (1.0 - c) + axis.y * s;
    X.w = 0.0;
    
    var Y = float4()
    Y.x = axis.x * axis.y * (1.0 - c) + axis.z * s;
    Y.y = axis.y * axis.y + (1.0 - axis.y * axis.y) * c;
    Y.z = axis.y * axis.z * (1.0 - c) - axis.x * s;
    Y.w = 0.0;
    
    var Z = float4()
    Z.x = axis.x * axis.z * (1.0 - c) - axis.y * s;
    Z.y = axis.y * axis.z * (1.0 - c) + axis.x * s;
    Z.z = axis.z * axis.z + (1.0 - axis.z * axis.z) * c;
    Z.w = 0.0;
    
    var W = float4()
    W.x = 0.0;
    W.y = 0.0;
    W.z = 0.0;
    W.w = 1.0;

    let mat = float4x4([X, Y, Z, W])
    return mat
}
//------------------------------------------------------------------------------
func PerspectiveProjection(aspect:Float, fovy:Float, near:Float, far:Float) -> float4x4
{
        let yScale:Float = 1.0 / tan(fovy * 0.5);
        let xScale:Float = yScale / aspect;
        let zRange:Float = far - near;
        let zScale:Float = -(far + near) / zRange;
        let wzScale:Float = -2.0 * far * near / zRange;
    
        let P = float4(xScale, 0.0, 0.0, 0.0 )
        let Q = float4(0.0, yScale, 0.0, 0.0 )
        let R = float4(0.0, 0.0, zScale, -1.0 )
        let S = float4(0.0, 0.0, wzScale, 0.0 )
   
    let mat = float4x4([P, Q, R, S ])
    return mat
}
//------------------------------------------------------------------------------
func UpperLeft3x3(mat4x4:float4x4) -> float3x3
{
    let P:float4 = mat4x4[0]
    let Q:float4 = mat4x4[1]
    let R:float4 = mat4x4[2]
    
    let X:float3 = float3(P.x, P.y, P.z)
    let Y:float3 = float3(Q.x, Q.y, Q.z)
    let Z:float3 = float3(R.x, R.y, R.z)
    
    let upperleft = float3x3([X, Y, Z])
    return upperleft
}
//------------------------------------------------------------------------------















