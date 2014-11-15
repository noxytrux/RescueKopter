//
//  KPTMapModel.swift
//  RescueKopter
//
//  Created by Marcin Pędzimąż on 15.11.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import Metal

class KPTMapModel: KPTModel {
   
    var heightMap: KPTHeightMap! = nil
    
    override func load(name: String, device: MTLDevice) -> (loaded: Bool, error: NSError?) {
    
        var matrixData = matrixStructure()
        matrixBuffer = device.newBufferWithBytes(&matrixData, length: sizeof(matrixStructure), options: nil)
        modelName = name
        
        var error:NSError? = nil
        var status: Bool = true
        
        //create current mesh Structure
        var subMeshBuffer = KPTMeshData()
       
        let texName = "grass"
        
        //load texture
        subMeshBuffer.diffuseTex = KPTSingletonFactory<KPTTextureManager>.sharedInstance().loadTexture(texName, device: device)
        
        if subMeshBuffer.diffuseTex == nil {
            
            subMeshBuffer.diffuseTex = KPTSingletonFactory<KPTTextureManager>.sharedInstance().loadTexture("checker", device: device)
            
            println("Warning no texture found for: \(texName)")
        }
        
        //generate height map
        heightMap = KPTHeightMap(filename: name)
        subMeshBuffer.vertexCount = UInt32(heightMap.w * heightMap.h)
       
        var vertexData = [geometryInfo]()
        var width:Float32 = Float32(heightMap.w)
        
        for(var x:Int = 0; x<heightMap.w; x++) {
        
            for(var y:Int = 0; y<heightMap.h; y++) {
            
                var vertexInfo = geometryInfo()
                
                vertexInfo.normal = heightMap.normalVectorAt(x, y: y)
                vertexInfo.texCoord = Vector2(x: Float32(x)/width, y: Float32(y)/width)
                vertexInfo.position = Vector3(x: -width + Float32(x) * 2.0, y: heightMap.At(x, y: y) / 8.0, z: -width + Float32(y) * 2.0)
                
                //println("pos: \(vertexInfo.position)")
                
                vertexData.append(vertexInfo)
            }
        }
        
        var size:Int = heightMap.w
        
        subMeshBuffer.faceCount = UInt32((size-1) * (size-1)) * 6
        
        var faceData = [UInt16](count: Int(subMeshBuffer.faceCount), repeatedValue: 0)
        var i:Int = 0
        
        for(var x:Int = 0; x < (size - 1); x++)
        {
            for(var y:Int = 0; y < (size - 1); y++)
            {
                faceData[i++] = UInt16((y * size) + x)
                faceData[i++] = UInt16(((y+1) * size) + (x + 1))
                faceData[i++] = UInt16(((y+1) * size) + x)
                faceData[i++] = UInt16((y * size) + x)
                faceData[i++] = UInt16(y * size + (x+1))
                faceData[i++] = UInt16(((y+1) * size) + (x + 1))
            }
        }
      
        subMeshBuffer.pipelineState = "basic"
        
        subMeshBuffer.vertexBuffer = device.newBufferWithBytes(vertexData, length:Int(subMeshBuffer.vertexCount) * sizeof(geometryInfo), options:nil)
        subMeshBuffer.indexBuffer = device.newBufferWithBytes(faceData, length:Int(subMeshBuffer.faceCount) * sizeof(UInt16), options: nil)
        
        subMeshData.append(subMeshBuffer)
        
        return (status, error)
    }
}
