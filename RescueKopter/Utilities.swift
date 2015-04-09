//
//  Utilities.swift
//  RescueKopter
//
//  Created by Marcin Pędzimąż on 15.11.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit
import QuartzCore

let kKPTDomain:String! = "KPTDomain"

struct imageStruct
{
    var width : Int = 0
    var height : Int = 0
    var bitsPerPixel : Int = 0
    var hasAlpha : Bool = false
    var bitmapData : UnsafeMutablePointer<Void>? = nil
}

func createImageData(name: String!,inout texInfo: imageStruct) {
    
    let baseImage = UIImage(named: name)
    let image: CGImageRef? = baseImage?.CGImage
    
    if let image = image {
        
        texInfo.width = CGImageGetWidth(image)
        texInfo.height = CGImageGetHeight(image)
        texInfo.bitsPerPixel = CGImageGetBitsPerPixel(image)
        texInfo.hasAlpha = CGImageGetAlphaInfo(image) != .None
        
        var sizeInBytes = texInfo.width * texInfo.height * texInfo.bitsPerPixel / 8
        var bytesPerRow = texInfo.width * texInfo.bitsPerPixel / 8
        
        texInfo.bitmapData = malloc(Int(sizeInBytes))
        
        let context : CGContextRef = CGBitmapContextCreate(
            texInfo.bitmapData!,
            texInfo.width,
            texInfo.height, 8,
            bytesPerRow,
            CGImageGetColorSpace(image),
            CGImageGetBitmapInfo(image))
        
        CGContextDrawImage(
            context,
            CGRectMake(0, 0, CGFloat(texInfo.width), CGFloat(texInfo.height)),
            image)
        
    }
    
}

func convertToRGBA(inout texInfo: imageStruct) {
    
    assert(texInfo.bitsPerPixel == 24, "Wrong image format")
    
    var stride = texInfo.width * 4
    var newPixels = malloc(stride * texInfo.height)
    
    var dstPixels = UnsafeMutablePointer<UInt32>(newPixels)
    
    var r: UInt8,
    g: UInt8,
    b: UInt8,
    a: UInt8
    
    a = 255
    
    var sourceStride = texInfo.width * texInfo.bitsPerPixel / 8
    var pointer = texInfo.bitmapData!
    
    for var j : Int = 0; j < texInfo.height; j++
    {
        for var i : Int = 0; i < sourceStride; i+=3 {
            
            var position : Int = Int(i + (sourceStride * j))
            var srcPixel = UnsafeMutablePointer<UInt8>(pointer + position)
            
            r = srcPixel.memory
            srcPixel++
            g = srcPixel.memory
            srcPixel++
            b = srcPixel.memory
            srcPixel++
            
            dstPixels.memory = (UInt32(a) << 24 | UInt32(b) << 16 | UInt32(g) << 8 | UInt32(r) )
            dstPixels++
        }
    }
    
    if let bitmapData = texInfo.bitmapData {
        
        free(texInfo.bitmapData!)
    }
    
    texInfo.bitmapData = newPixels
    texInfo.bitsPerPixel = 32
    texInfo.hasAlpha = true
}

struct mapDataStruct {
    
    var object: UInt32 //BGRA!
    
    var playerSpawn: UInt8 {
        
        return UInt8(object & 0x000000FF)
    }
    
    var ground: UInt8 {
        
        return UInt8((object & 0x0000FF00) >> 8)
    }
    
    var grass: UInt8 {
        
        return UInt8((object & 0x00FF0000) >> 16)
    }
    
    var wall: UInt8 {
        
        return UInt8((object & 0xFF000000) >> 24)
    }
    
    var desc : String {
        
        return "(\(self.ground),\(self.grass),\(self.wall),\(self.playerSpawn))"
    }
}

func makeNormal(x1:Float32, y1:Float32, z1:Float32,
    x2:Float32, y2:Float32, z2:Float32,
    x3:Float32, y3:Float32, z3:Float32,
    inout rx:Float32, inout ry:Float32, inout rz:Float32 )
{
    var ax:Float32 = x3-x1,
    ay:Float32 = y3-y1,
    az:Float32 = z3-z1,
    bx:Float32 = x2-x1,
    by:Float32 = y2-y1,
    bz:Float32 = z2-z1
    
    rx = ay*bz - by*az
    ry = bx*az - ax*bz
    rz = ax*by - bx*ay
}

func createARGBBitmapContext(inImage: CGImage) -> CGContext {
    
    var bitmapByteCount = 0
    var bitmapBytesPerRow = 0
    
    let pixelsWide = CGImageGetWidth(inImage)
    let pixelsHigh = CGImageGetHeight(inImage)
    
    bitmapBytesPerRow = Int(pixelsWide) * 4
    bitmapByteCount = bitmapBytesPerRow * Int(pixelsHigh)
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapData = malloc(Int(bitmapByteCount))
    let bitmapInfo = CGBitmapInfo( UInt32(CGImageAlphaInfo.PremultipliedFirst.rawValue) )
    
    let context = CGBitmapContextCreate(bitmapData,
        pixelsWide,
        pixelsHigh,
        Int(8),
        Int(bitmapBytesPerRow),
        colorSpace,
        bitmapInfo)
    
    return context
}

func loadMapData(mapName: String) -> (data: UnsafeMutablePointer<Void>, width: Int, height: Int) {
    
    let image = UIImage(named: mapName)
    let inImage = image?.CGImage
    
    let cgContext = createARGBBitmapContext(inImage!)
    
    let imageWidth = CGImageGetWidth(inImage)
    let imageHeight = CGImageGetHeight(inImage)
    
    var rect = CGRectZero
    rect.size.width = CGFloat(imageWidth)
    rect.size.height = CGFloat(imageHeight)
    
    CGContextDrawImage(cgContext, rect, inImage)
    
    let dataPointer = CGBitmapContextGetData(cgContext)
    
    return (dataPointer, imageWidth, imageHeight)
}

