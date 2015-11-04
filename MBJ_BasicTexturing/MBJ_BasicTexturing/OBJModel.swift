//
//  OBJModel.mm
//  UpAndRunning3D
//
//  Created by Warren Moore on 9/11/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//------------------------------------------------------------------------
//  converted to Swift by Jamnitzer (Jim Wrenholt)
//------------------------------------------------------------------------
import UIKit
import simd

import Metal
import Foundation
import Accelerate

//-------------------------------------------------------------------------
// "Face vertices" are tuples of indices into file-wide lists
// of positions, normals, and texture coordinates.
// We maintain a mapping from these triples to the indices
// they will eventually occupy in the group that
// is currently being constructed.
//-------------------------------------------------------------------------
struct FaceVertex
{
    var vi:UInt16 = 0
    var ti:UInt16 = 0
    var ni:UInt16 = 0
}
//------------------------------------------------------------------------------
func <(v0: FaceVertex, v1: FaceVertex) -> Bool
{
    if (v0.vi < v1.vi)
    {
        return true
    }
    else if (v0.vi > v1.vi)
    {
        return false
    }
    else if (v0.ti < v1.ti)
    {
        return true
    }
    else if (v0.ti > v1.ti)
    {
        return false
    }
    else if (v0.ni < v1.ni)
    {
        return true
    }
    else if (v0.ni > v1.ni)
    {
        return false
    }
    else
    {
        return false
    }
}
//------------------------------------------------------------------------------
func ==(lhs: FaceVertex, rhs: FaceVertex) -> Bool
{
    return lhs.vi == rhs.vi && lhs.ti == rhs.ti && lhs.ni == rhs.ni
}
//------------------------------------------------------------------------------
//
//------------------------------------------------------------------------------
class OBJModel
{
    typealias IndexType = UInt16
    
    var vertices:[float4] = []
    var normals:[float3] = []
    var texCoords:[float2] = []
    var groupVertices:[Vertex] = []
    var groupIndices:[IndexType] = []
    var vertexToGroupIndexMap:[(FaceVertex, IndexType)] = []
    
    var groups:[OBJGroup] = []
    var shouldGenerateNormals:Bool = false
    var currentGroup:OBJGroup? = nil
    
    //-------------------------------------------------------------------------
    // Index 0 corresponds to an unnamed group that collects all the geometry
    // declared outside of explicit "g" statements. Therefore, if your file
    // contains explicit groups, you'll probably want to start from index 1,
    // which will be the group defined starting at the first group statement.
    //-------------------------------------------------------------------------
    var name:String = "OBJModel"
    
    //-------------------------------------------------------------------------
    init(fileURL:NSURL, generateNormals:Bool)
    {
        shouldGenerateNormals = generateNormals
        groups = [OBJGroup]()
        parseModelAtURL(fileURL)
    }
    //-------------------------------------------------------------------------
    func getGroups() -> [OBJGroup]
    {
        return groups
    }
    //-------------------------------------------------------------------------
    func parseModelAtURL(url:NSURL)
    {
        //---------------------------------------
        // get contents of URL.
        //---------------------------------------
        var urlContents:NSString
        do { urlContents = try
            NSString(contentsOfURL: url, encoding: NSASCIIStringEncoding) }
        catch let urlError as NSError {
            print("URL Contents error \(urlError)")
            return
        }
        //---------------------------------------
        // create a scanner for parse.
        //---------------------------------------
        let scanner = NSScanner(string: urlContents as String)
        let skipSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        let consumeSet = skipSet.invertedSet
        scanner.charactersToBeSkipped = skipSet
        
        let endlineCharacters = NSCharacterSet.newlineCharacterSet()
        
        beginGroupWithName("unnamed")
        
        while (!scanner.atEnd)
        {
            var token: NSString? = nil
            if (!scanner.scanCharactersFromSet(consumeSet, intoString:&token))
            {
                break
            }
            if (token == "v")
            {
                var x:Float = 0.0
                var y:Float = 0.0
                var z:Float = 0.0
                scanner.scanFloat(&x)
                scanner.scanFloat(&y)
                scanner.scanFloat(&z)
                let v = float4(x, y, z, 1.0)
                vertices.append(v)
            }
            else if (token == "vt")
            {
                var u:Float = 0.0
                var v:Float = 0.0
                scanner.scanFloat(&u)
                scanner.scanFloat(&v)
                let vt = float2(u, v)
                texCoords.append(vt)
            }
            else if (token == "vn")
            {
                var nx:Float = 0.0
                var ny:Float = 0.0
                var nz:Float = 0.0
                scanner.scanFloat(&nx)
                scanner.scanFloat(&ny)
                scanner.scanFloat(&nz)
                let vn = float3(nx, ny, nz)
                normals.append(vn)
            }
            else if (token == "f")
            {
                var faceVertices = [FaceVertex]()
                while (true)
                {
                    var vi:Int32 = 0
                    var ti:Int32 = 0
                    var ni:Int32 = 0
                    if (!scanner.scanInt(&vi))
                    {
                        break
                    }
                    //----------------------------------------------
                    if (scanner.scanString("/", intoString:nil))
                    {
                        scanner.scanInt(&ti)
                        //------------------------------------------
                        if (scanner.scanString("/", intoString:nil))
                        {
                            scanner.scanInt(&ni)
                        }
                        //------------------------------------------
                    }
                    //----------------------------------------------
                    // OBJ format allows relative vertex references
                    // in the form of negative indices,
                    // and dictates that indices are 1-based.
                    // Below, we simultaneously fix up negative indices
                    // and offset everything by -1 to
                    // allow 0-based indexing later on.
                    //-------------------------------------------
                    var faceVertex = FaceVertex()
                    //-------------------------------------------
                    faceVertex.vi = UInt16(vi - 1)
                    faceVertex.ti = UInt16(ti - 1)
                    faceVertex.ni = UInt16(ni - 1)
                    //-------------------------------------------
                    if (vi < 0)
                    {
                        faceVertex.vi = UInt16(vertices.count + vi - 1 )
                    }
                    if (ti < 0)
                    {
                        faceVertex.ti = UInt16(texCoords.count + ti - 1 )
                    }
                    if (ni < 0)
                    {
                        faceVertex.ni = UInt16(normals.count + ni - 1 )
                    }
                    //-------------------------------------------
                    faceVertices.append(faceVertex)
                }
                addFaceWithFaceVertices(faceVertices)
            }
            else if (token == "g")
            {
                var groupName:NSString? = nil
                if scanner.scanUpToCharactersFromSet(endlineCharacters, intoString:&groupName)
                {
                    beginGroupWithName((groupName as? String)!)
                }
            }
        }
        endCurrentGroup()
    }
    //-------------------------------------------------------------------------
    func beginGroupWithName(name:String)
    {
        endCurrentGroup()
        //--------------------------------------------------
        let newGroup:OBJGroup = OBJGroup(name: String(name))
        self.groups.append(newGroup)
        self.currentGroup = newGroup
    }
    //-----------------------------------------------------------------------------
    func endCurrentGroup()
    {
        if (self.currentGroup == nil)
        {
            return
        }
        //------------------------------------------------------------------
        if (self.shouldGenerateNormals)
        {
            self.generateNormalsForCurrentGroup()
        }
        //------------------------------------------------------------------
        // Once we've read a complete group,
        // we copy the packed vertices that have been referenced
        // by the group into the current group object.
        // Because it's fairly uncommon to have cross-group shared vertices,
        // this essentially divides up the vertices into disjoint sets by group.
        //------------------------------------------------------------------
        let vertexData : NSData = NSData(bytes: groupVertices,
            length: sizeof(Vertex) * groupVertices.count)
        self.currentGroup!.vertexData = vertexData
        //------------------------------------------------------------------
        let indexData : NSData = NSData(bytes: groupIndices,
            length: sizeof(IndexType) * groupIndices.count)
        self.currentGroup!.indexData = indexData
        //------------------------------------------------------------------
        groupVertices = [Vertex]()
        groupIndices = [IndexType]()
        vertexToGroupIndexMap = [(FaceVertex, IndexType)]()
        
        self.currentGroup = nil
    }
    //-------------------------------------------------------------------------
    func generateNormalsForCurrentGroup()
    {
        let ZERO3 = float3(0.0, 0.0, 0.0)
        let vertexCount = groupVertices.count
        for (var i:Int = 0; i < vertexCount; ++i)
        {
            groupVertices[i].normal = ZERO3
        }
        let indexCount:Int = groupIndices.count
        for (var i:Int = 0; i < indexCount; i += 3)
        {
            let i0 = Int(groupIndices[i])
            let i1 = Int(groupIndices[i+1])
            let i2 = Int(groupIndices[i+2])
            
            var v0:Vertex = groupVertices[i0]
            var v1:Vertex = groupVertices[i1]
            var v2:Vertex = groupVertices[i2]
            
            let q0:float4 = v0.position
            let q1:float4 = v1.position
            let q2:float4 = v2.position
            
            let p0:float3 = float3(q0.x, q0.y, q0.z)
            let p1:float3 = float3(q1.x, q1.y, q1.z)
            let p2:float3 = float3(q2.x, q2.y, q2.z)
            
            let vcross:float3 = cross((p1 - p0), (p2 - p0))
            v0.normal += vcross
            v1.normal += vcross
            v2.normal += vcross
            
            groupVertices[i0] = v0
            groupVertices[i1] = v1
            groupVertices[i2] = v2
        }
        
        for (var i:Int = 0; i < vertexCount; ++i)
        {
            groupVertices[i].normal = normalize(groupVertices[i].normal)
        }
    }
    //-------------------------------------------------------------------------
    func addFaceWithFaceVertices(faceVertices:[FaceVertex])
    {
        //--------------------------------------------------------
        // Transform polygonal faces into "fans" of triangles,
        // three vertices at a time
        //--------------------------------------------------------
        for (var i:Int = 0; i < faceVertices.count - 2; ++i)
        {
            addVertexToCurrentGroup(faceVertices[0])
            addVertexToCurrentGroup(faceVertices[i + 1])
            addVertexToCurrentGroup(faceVertices[i + 2])
        }
    }
    //-------------------------------------------------------------------------
    func addVertexToCurrentGroup(fv:FaceVertex)
    {
        let UP = float3(0.0, 1.0, 0.0)
        let ZERO2 = float2(0.0, 0.0 )
        let INVALID_INDEX:UInt16 = 0xffff
        
        var groupIndex:UInt16 = 0
        var hasFoundVertex: Bool = false
        for (fg, fi) in vertexToGroupIndexMap
        {
            if (fg == fv)
            {
                groupIndex = fi
                hasFoundVertex = true
                break
            }
        }
        if !hasFoundVertex
        {
            var vertex = Vertex()
            vertex.position = vertices[Int(fv.vi)]
            vertex.normal = (fv.ni != INVALID_INDEX) ? normals[Int(fv.ni)] : UP
            vertex.texCoords = (fv.ti != INVALID_INDEX) ? texCoords[Int(fv.ti)] : ZERO2
            
            groupVertices.append(vertex)
            groupIndex = UInt16(groupVertices.count - 1)
            vertexToGroupIndexMap.append((fv, groupIndex))
        }
        groupIndices.append(groupIndex)
    }
    //-------------------------------------------------------------------------
    //-------------------------------------------------------------------------
}
//------------------------------------------------------------------------------
