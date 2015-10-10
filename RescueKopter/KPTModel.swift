//
//  KPTModel.swift
//  RescueKopter
//
//  Created by Marcin Pędzimąż on 15.11.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import Metal

import UIKit
import Metal

let kKPTModelHeder: UInt16 = 0xB3D0

struct geometryInfo {
    
    var position = Vector3()
    var normal = Vector3()
    var texCoord = Vector2()
}

struct KPTMeshData {
    
    //texture used to draw
    var diffuseTex: MTLTexture? = nil
    
    //geometry info
    var vertexBuffer: MTLBuffer? = nil
    var indexBuffer: MTLBuffer? = nil
    
    //shader
    var pipelineState: String? = nil
    
    //front back facing ?
    var cullMode: MTLCullMode = .Back
    
    var faceCount: UInt32 = 0
    var vertexCount: UInt32 = 0
}

class KPTModel {
    
    internal var subMeshData = [KPTMeshData]()
    internal var modelName: String = ""
    
    internal var modelScale: Float32 = 1.0
    internal var modelMatrix: Matrix34! = nil
    internal var matrixBuffer: MTLBuffer! = nil
    
    init() {
        
        modelMatrix  = Matrix34(initialize: true)
    }
    
    func setCullModeForMesh(atIndex: Int, mode: MTLCullMode) {
        
        subMeshData[atIndex].cullMode  = mode
    }
    
    func setPipelineState(atIndex:Int, name: String) {
    
        subMeshData[atIndex].pipelineState = name
    }
    
    func setTexture(atIndex:Int, texture:MTLTexture) {
    
        subMeshData[atIndex].diffuseTex = texture
    }
    
    //based on B3DO model file format
    func load(name: String, device: MTLDevice) -> (loaded: Bool, error: NSError?) {
        
        //generate unique buffer for model
        var matrixData = matrixStructure()
        matrixBuffer = device.newBufferWithBytes(&matrixData, length: sizeof(matrixStructure), options: .CPUCacheModeDefaultCache)
        
        
        modelName = name
        
        var error:NSError? = nil
        var status: Bool = true
        
        let path = NSBundle.mainBundle().pathForResource(name, ofType: "gmf")
        
        if let path = path {
            
            var header:UInt16 = 0
            
            var mindex:UInt32 = 0, index:UInt32 = 0
            var c:CChar = 0
            var namestr = Array<CChar>(count: 256, repeatedValue: 0)
            
            let readStream:NSFileHandle? = NSFileHandle(forReadingAtPath: path)
            
            if let readStream = readStream {
                
                //readStream.seekToFileOffset(0)
                
                var data = readStream.readDataOfLength(sizeof(UInt16))
                data.getBytes(&header, length: sizeof(UInt16))
                
                if header == kKPTModelHeder {
                    
                    var bufferCount : UInt32 = 0
                    
                    data = readStream.readDataOfLength(sizeof(UInt32))
                    data.getBytes(&bufferCount, length: sizeof(UInt32))
                    
                    for(mindex = 0; mindex < bufferCount; mindex++)
                    {
                        
                        index = 0;
                        
                        repeat
                        {
                            data = readStream.readDataOfLength(sizeof(CChar))
                            data.getBytes(&c, length: sizeof(CChar))
                            
                            namestr[Int(index)] = c
                            index++;
                        }
                            while((c != 0) && (index < 256))
                        
                        namestr[255] = 0
                        
                        let texName = String.fromCString(namestr)!
                        
                        print("Mesh: \(texName)")
                        
                        //create current mesh Structure
                        var subMeshBuffer = KPTMeshData()
                        
                        //load texture
                        subMeshBuffer.diffuseTex = KPTTextureManager.sharedInstance.loadTexture(texName, device: device)
                        
                        if subMeshBuffer.diffuseTex == nil {
                            
                            subMeshBuffer.diffuseTex = KPTTextureManager.sharedInstance.loadTexture("checker", device: device)
                            
                            print("Warning no texture found for: \(texName)")
                        }
                        
                        data = readStream.readDataOfLength(sizeof(UInt32))
                        data.getBytes(&subMeshBuffer.vertexCount, length:sizeof(UInt32))
                        
                        data = readStream.readDataOfLength(sizeof(UInt32))
                        var fCount:UInt32 = 0
                        
                        data.getBytes(&fCount, length:sizeof(UInt32))
                        
                        subMeshBuffer.faceCount = fCount * 3
                        
                        var vertexData = [geometryInfo]()
                        var faceData = [UInt16](count: Int(subMeshBuffer.faceCount), repeatedValue: 0)
                        
                        //load vertex data
                        for(index = 0; index < subMeshBuffer.vertexCount; index++)
                        {
                            var vertexInfo = geometryInfo()
                            
                            data = readStream.readDataOfLength(sizeof(Vector3))
                            data.getBytes(&vertexInfo.position, length: sizeof(Vector3))
                            
                            data = readStream.readDataOfLength(sizeof(Vector2))
                            data.getBytes(&vertexInfo.texCoord, length: sizeof(Vector2))
                            
                            data = readStream.readDataOfLength(sizeof(Vector3))
                            data.getBytes(&vertexInfo.normal, length: sizeof(Vector3))
                            
                            vertexData.append(vertexInfo)
                            
                            //println("pos: \(position) normal: \(normal) coord: \(coord)")
                        }
                        
                        var px:Int32 = 0,py:Int32 = 0,pz:Int32 = 0
                        
                        //load face indexes
                        for(index = 0; index < fCount; index++)
                        {
                            
                            data = readStream.readDataOfLength(sizeof(Int32))
                            data.getBytes(&px, length: sizeof(Int32))
                            data = readStream.readDataOfLength(sizeof(Int32))
                            data.getBytes(&py, length: sizeof(Int32))
                            data = readStream.readDataOfLength(sizeof(Int32))
                            data.getBytes(&pz, length: sizeof(Int32))
                            
                            //seek by  3 * sizeof(Int32) (here is face normal)
                            data = readStream.readDataOfLength(sizeof(Int32) * 3)
                            
                            faceData[Int(index * 3 + 0)] = UInt16(px)
                            faceData[Int(index * 3 + 1)] = UInt16(py)
                            faceData[Int(index * 3 + 2)] = UInt16(pz)
                            
                            //println("Face: \(px),\(py),\(pz)")
                        }
                        
                        subMeshBuffer.pipelineState = "basic" //you may want to load this from some material file
                        
                        subMeshBuffer.vertexBuffer = device.newBufferWithBytes(vertexData, length:Int(subMeshBuffer.vertexCount) * sizeof(geometryInfo), options: .CPUCacheModeDefaultCache)
                        subMeshBuffer.indexBuffer = device.newBufferWithBytes(faceData, length:Int(subMeshBuffer.faceCount) * sizeof(UInt16), options: .CPUCacheModeDefaultCache)
                        
                        //store geometry info
                        subMeshData.append(subMeshBuffer)
                    }//for meshindex
                    
                }
                else {
                    
                    status = false
                    error = NSError(domain:kKPTDomain , code: NSFileReadInvalidFileNameError, userInfo: [NSLocalizedDescriptionKey : "File does not exist."])
                }
                
                readStream.closeFile()
            }
            
        }
        else {
            status = false
            error = NSError(domain:kKPTDomain , code: NSFileNoSuchFileError, userInfo: [NSLocalizedDescriptionKey : "File does not exist."])
        }
        
        return (status, error)
    }
    
    func render(encoder: MTLRenderCommandEncoder, states: [String : MTLRenderPipelineState], shadowPass: Bool) {
        
        encoder.pushDebugGroup("rendering: \(modelName)")
        
        for subMesh in subMeshData {
            
            let pipelineState = states[subMesh.pipelineState!]
            
            if let pipelineState = pipelineState {
                
                encoder.setRenderPipelineState(pipelineState);
                
                if shadowPass == true {
                    
                    encoder.setCullMode(.Front)
                }
                else{
                    
                    encoder.setCullMode(subMesh.cullMode)
                }
                
                encoder.setFragmentTexture(subMesh.diffuseTex, atIndex: 0)
                encoder.setVertexBuffer(subMesh.vertexBuffer!, offset: 0, atIndex: 0)
                
                encoder.drawIndexedPrimitives(.Triangle,
                    indexCount: Int(subMesh.faceCount),
                    indexType: .UInt16,
                    indexBuffer: subMesh.indexBuffer!,
                    indexBufferOffset: 0)
                
            }
        }
        
        encoder.popDebugGroup()
    }
}
