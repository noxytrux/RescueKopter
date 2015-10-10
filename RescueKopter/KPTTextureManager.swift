//
//  KPTTextureManager.swift
//  RescueKopter
//
//  Created by Marcin Pędzimąż on 15.11.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit
import Metal

class KPTTextureManager  {
    
    static let sharedInstance = KPTTextureManager()
    
    private var textureCache = [String: MTLTexture]()
    
    required init() {
        
    }
    
    func loadTexture(name: String!, device: MTLDevice!) -> MTLTexture? {
        
        let texture = textureCache[name]
        
        if let texture = texture {
            
            return texture
        }
        
        var texStruct = imageStruct()
        
        createImageData(name, texInfo: &texStruct)
        
        if let _ = texStruct.bitmapData {
            
            if texStruct.hasAlpha == false && texStruct.bitsPerPixel >= 24 {
                
                convertToRGBA(&texStruct)
            }
            
            let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.RGBA8Unorm,
                width: Int(texStruct.width),
                height: Int(texStruct.height),
                mipmapped: true)
            
            let loadedTexture = device.newTextureWithDescriptor(descriptor)
            
            loadedTexture.replaceRegion(
                MTLRegionMake2D(0, 0, Int(texStruct.width),Int(texStruct.height)),
                mipmapLevel: 0,
                withBytes: texStruct.bitmapData!,
                bytesPerRow: Int(texStruct.width * texStruct.bitsPerPixel / 8))
            
            free(texStruct.bitmapData!)
            
            textureCache[name] = loadedTexture
            
            return loadedTexture
        }
        
        return nil
    }
    
    func loadCubeTexture(name: String!, device: MTLDevice!) -> MTLTexture? {
        
        let texture = textureCache[name]
        
        if let texture = texture {
            
            return texture
        }
        
        var texStruct = imageStruct()
        
        createImageData(name, texInfo: &texStruct)
        
        if let _ = texStruct.bitmapData {
            
            if texStruct.hasAlpha == false && texStruct.bitsPerPixel >= 24 {
                
                convertToRGBA(&texStruct)
            }
            
            let bytesPerImage = Int(texStruct.width * texStruct.width * 4)
            
            let descriptor = MTLTextureDescriptor.textureCubeDescriptorWithPixelFormat(.RGBA8Unorm,
                size: Int(texStruct.width),
                mipmapped: false)
            
            let loadedTexture = device.newTextureWithDescriptor(descriptor)
            
            for index in 0...5 {
                
                loadedTexture.replaceRegion(
                    MTLRegionMake2D(0, 0, Int(texStruct.width),Int(texStruct.width)),
                    mipmapLevel: 0,
                    slice: Int(index),
                    withBytes: (texStruct.bitmapData!) + Int(index * bytesPerImage),
                    bytesPerRow: Int(texStruct.width) * 4,
                    bytesPerImage: bytesPerImage)
            }
            
            free(texStruct.bitmapData!)
            
            textureCache[name] = loadedTexture
            
            return loadedTexture
        }
        
        return nil
    }
}
