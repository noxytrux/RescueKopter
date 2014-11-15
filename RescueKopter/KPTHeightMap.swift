//
//  KPTHeightMap.swift
//  RescueKopter
//
//  Created by Marcin Pędzimąż on 15.11.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit

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

class KPTHeightMap {
   
    private var rawData: UnsafeMutablePointer<Void>! = nil
    private var rawNormals: UnsafeMutablePointer<Void>! = nil
    
    internal var data = UnsafeMutablePointer<Float32>()
    internal var normal = UnsafeMutablePointer<Float32>()
    internal var w: Int = 0
    internal var h: Int = 0
    
    init(filename: String) {
    
        var texStruct = imageStruct()
        
        createImageData(filename, &texStruct)
        
        if let bitmapData = texStruct.bitmapData {
            
            if texStruct.hasAlpha == false && texStruct.bitsPerPixel >= 24 {
                
                convertToRGBA(&texStruct)
            }
            
            //create data and normal info
            
            w = Int(texStruct.width)
            h = Int(texStruct.height)
            
            rawData = malloc(texStruct.width * texStruct.height)
            rawNormals = malloc(texStruct.width * texStruct.height)
            
            data = UnsafeMutablePointer<Float32>(rawData)
            normal = UnsafeMutablePointer<Float32>(rawNormals)
    
            var b = texStruct.bitmapData!
            var memSize = (w * h)
            
            var index:Int = 0
            
            while(index < memSize) {
                
                var src = UnsafeMutablePointer<UInt8>(b + index)
                
                //println("(\(index) / \(memSize)) dst: \(data.memory) src: \(src.memory)")
                
                data.memory = Float32(src.memory)
                data++
                
                index += 4
            }
            
            //normals calcualtion
            
            var ax:Float32 = 0,
            ay:Float32 = 0,
            az:Float32 = 0,
            sx:Float32 = 0,
            sy:Float32 = 0,
            sz:Float32 = 0,
            cx:Float32 = 0,
            cy:Float32 = 0

            var x:Int = 0, y:Int = 0
            
            for( x = 0; x < w; x++) {
            for( y = 0; y < h; y++) {
                
                sx = 0
                sy = 0
                sz = 0
                
                cx = Float32(x) * 2.0
                cy = Float32(y) * 2.0
                
//                makeNormal( cx, At(x,y:y),cy ,cx+2, At(x+1,y:y-1),cy-2, cx+2,At(x+1,y:y),cy, &ax, &ay, &az )
//                sx += ax
//                sy += ay
//                sz += az
//                
//                makeNormal( cx, At(x,y:y),cy ,cx+2, At(x+1,y:y),cy,cx, At(x,y:y+1),cy+2, &ax, &ay, &az )
//                sx += ax
//                sy += ay
//                sz += az
//                
//                makeNormal( cx, At(x,y:y),cy ,cx ,At(x,y:y+1),cy+2, cx-2,At(x-1,y:y+1),cy+2, &ax, &ay, &az )
//                sx += ax
//                sy += ay
//                sz += az
//                
//                makeNormal( cx, At(x,y:y),cy ,cx-2 ,At(x-1,y:y+1),cy+2, cx-2,At(x-1,y:y),cy, &ax, &ay, &az )
//                sx += ax
//                sy += ay
//                sz += az
//                
//                makeNormal( cx, At(x,y:y),cy ,cx-2 ,At(x-1,y:y),cy, cx,At(x,y:y-1),cy-2, &ax, &ay, &az )
//                sx += ax
//                sy += ay
//                sz += az
                
                var N = normAt(x, y: y, d:0)
                
                N[ 0 ] = 0 //sx
                N[ 1 ] = 1 //sy
                N[ 2 ] = 0 //sz
                
                //println("Normal(\(N[0]),\(N[1]),\(N[2]))")
                
                var l:Float32 = sqrt(sx*sx + sy*sy + sz*sz)
                
                if l > 0.0001 {
                    
                    N[ 0 ] = sx / l
                    N[ 1 ] = sy / l
                    N[ 2 ] = sz / l
                }
                
            }
            }
        }
    }
    
    func At(x:Int, y:Int) -> Float32 {
    
        if x < 0 || y < 0 || x >= w || y >= h {
        
            return 0
        }
        
        var vertexIndex: Int = x + y * w
        
        return data[vertexIndex]
    }
    
    func normAt(x:Int, y:Int, d:Int) -> UnsafeMutablePointer<Float32> {
    
        if x < 0 || y < 0 || x >= w || y >= h {
        
            var empty = UnsafeMutablePointer<Float32>.alloc(3)
                empty.initialize(0)
            
            return empty
        }
        
        var index: Int = ( x + y * w ) * 3 + d
        
        return UnsafeMutablePointer<Float32>(normal + index)
    }
    
    func normalVectorAt(x:Int, y:Int, d:Int) -> Vector3 {
    
        var N = normAt(x, y: y, d:d)
        
        return Vector3(x:N[0],y:N[1],z:N[2])
    }
    
    func GetHeight(x: Float32, z:Float32 ) -> Float32 {
        
        var rx = x
        var rz = z
        
        var a: Int = Int(x)
        var b: Int = Int(z)
        
        if a < 0 || b < 0 || a > w-1 || b > h-1 {
            
            return 0.0
        }
    
        rx -= Float32(a)
        rz -= Float32(b)
        
        if( rz < 0.001 ) {
            
            return mix( At(a,y:b) ,At(a+1,y:b) , x )
        }
        
        if( x < 0.001 ) {
        
            return mix( At(a,y:b) ,At(a,y:b+1) , z )
        }
        
        if( x < z )
        {
            
            var w1 = z*( At(a,y:b+1) - At(a,y:b) ) + At(a,y:b)
            var w2 = z*( At(a+1,y:b+1) - At(a,y:b) ) + At(a,y:b)
            
            return w1 + x/z*( w2 - w1 )
            
        }
        else
        {
            
            var w1 = x*( At(a+1,y:b) - At(a,y:b) ) + At(a,y:b)
            var w2 = x*( At(a+1,y:b+1) - At(a,y:b) ) + At(a,y:b)
            
            return w1 + z/x*( w2 - w1 )
        }
        
    }
    
    func GetNormal(x:Float32, z:Float32) -> Vector3 {
    
        var a = Int(x)
        var b = Int(z)
        var v = Vector3(x:0.0, y:1.0, z:0.0)
        
        if( a < 0 || b < 0 || a > w-1 || b > h-1 ) {
        
           return v
        }
    
        var w1:Float32 = 0, w2:Float32 = 0
    
        var rx = x
        var rz = z
        
        rx -= Float32(a)
        rz -= Float32(b)
        
        w1 = z * ( normalVectorAt(a,y:b+1,d:0).x - normalVectorAt(a,y:b,d:0).x ) + normalVectorAt(a,y:b,d:0).x
        w2 = z * ( normalVectorAt(a+1,y:b+1,d:0).x - normalVectorAt(a+1,y:b,d:0).x ) + normalVectorAt(a+1,y:b,d:0).x
        
        v.x =  w1 + x*( w2 - w1 )
        
        w1 = z * ( normalVectorAt(a,y:b+1,d:1).x - normalVectorAt(a,y:b,d:1).x ) + normalVectorAt(a,y:b,d:1).x
        w2 = z * ( normalVectorAt(a+1,y:b+1,d:1).x - normalVectorAt(a+1,y:b,d:1).x ) + normalVectorAt(a+1,y:b,d:1).x
        
        v.y =  w1 + x*( w2 - w1 )
        
        w1 = z * ( normalVectorAt(a,y:b+1,d:2).x - normalVectorAt(a,y:b,d:2).x ) + normalVectorAt(a,y:b,d:2).x
        w2 = z * ( normalVectorAt(a+1,y:b+1,d:2).x - normalVectorAt(a+1,y:b,d:2).x ) + normalVectorAt(a+1,y:b,d:2).x
        
        v.z =  w1 + x*( w2 - w1 )

        v.normalize()
        
        return v
    }
    
    deinit {
    
        free(rawData)
        free(rawNormals)
    }
}
