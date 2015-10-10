//
//  KPTHeightMap.swift
//  RescueKopter
//
//  Created by Marcin Pędzimąż on 15.11.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit

class KPTHeightMap {
   
    internal var data = [Float32]()
    internal var normal = [Float32]()
    internal var w: Int = 0
    internal var h: Int = 0
    
    init(filename: String) {
    
        let mapData = loadMapData(filename)
        
        w = Int(mapData.width)
        h = Int(mapData.height)
        
        data = [Float32](count: w*h, repeatedValue: 0.0)
        normal = [Float32](count: w*h*3, repeatedValue: 0.0)
        
        var index:Int = 0
        
        let dataStruct = UnsafePointer<mapDataStruct>(mapData.data)
        
        for var ax=0; ax < w; ax++ {
            for var ay=0; ay < h; ay++ {
                
                let imgData = dataStruct[ax + ay * w]
                data[index] = Float32(imgData.ground)
                index++
            }
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
                
                makeNormal( cx, y1: At(x,y:y),z1: cy ,x2: cx+2, y2: At(x+1,y:y-1),z2: cy-2, x3: cx+2,y3: At(x+1,y:y),z3: cy, rx: &ax, ry: &ay, rz: &az )
                sx += ax
                sy += ay
                sz += az
                
                makeNormal( cx, y1: At(x,y:y),z1: cy ,x2: cx+2, y2: At(x+1,y:y),z2: cy,x3: cx, y3: At(x,y:y+1),z3: cy+2, rx: &ax, ry: &ay, rz: &az )
                sx += ax
                sy += ay
                sz += az
                
                makeNormal( cx, y1: At(x,y:y),z1: cy ,x2: cx ,y2: At(x,y:y+1),z2: cy+2, x3: cx-2,y3: At(x-1,y:y+1),z3: cy+2, rx: &ax, ry: &ay, rz: &az )
                sx += ax
                sy += ay
                sz += az
                
                makeNormal( cx, y1: At(x,y:y),z1: cy ,x2: cx-2 ,y2: At(x-1,y:y+1),z2: cy+2, x3: cx-2,y3: At(x-1,y:y),z3: cy, rx: &ax, ry: &ay, rz: &az )
                sx += ax
                sy += ay
                sz += az
                
                makeNormal( cx, y1: At(x,y:y),z1: cy ,x2: cx-2 ,y2: At(x-1,y:y),z2: cy, x3: cx,y3: At(x,y:y-1),z3: cy-2, rx: &ax, ry: &ay, rz: &az )
                sx += ax
                sy += ay
                sz += az
                
                updateNormal(x, y: y, nx: sx, ny: sy, nz: sz)
                
            }
        }
    }
    
    func updateNormal(x:Int,y:Int, nx:Float32, ny:Float32, nz:Float32) {
    
        let index: Int = ( x + y * w ) * 3
    
        let l:Float32 = sqrt(nx*nx + ny*ny + nz*nz)
        
        if l > 0.0001 {
            
            normal[ index+0 ] = nx / l
            normal[ index+1 ] = ny / l
            normal[ index+2 ] = nz / l
        }
        else {
        
            normal[index+0] = nx
            normal[index+1] = ny
            normal[index+2] = nz
        }
    }
    
    func At(x:Int, y:Int) -> Float32 {
    
        if x < 0 || y < 0 || x >= w || y >= h {
        
            return 0
        }
        
        let vertexIndex: Int = x + y * w
        
        return data[vertexIndex]
    }
    
    func normAt(x:Int, y:Int, d:Int) -> Float32 {
    
        var rx = x
        var ry = y
        
        if x < 0 || y < 0 || x >= w || y >= h {
        
            rx = 0
            ry = 0
        }
        
        let index: Int = ( rx + ry * w ) * 3 + d
        
        return normal[index]
    }
    
    func normalVectorAt(x:Int,y:Int) -> Vector3 {
    
        let nx = normAt(x, y: y, d: 0)
        let ny = normAt(x, y: y, d: 1)
        let nz = normAt(x, y: y, d: 2)
        
        return Vector3(x:nx, y:ny, z:nz)
    }
    
    func GetHeight(x: Float32, z:Float32 ) -> Float32 {
        
        var rx = x
        var rz = z
        
        let a: Int = Int(x)
        let b: Int = Int(z)
        
        if a < 0 || b < 0 || a > w-1 || b > h-1 {
            
            return 0.0
        }
    
        rx -= Float32(a)
        rz -= Float32(b)
        
        if( rz < 0.001 ) {
            
            return mix( At(a,y:b) ,b: At(a+1,y:b) , f: rx )
        }
        
        if( rx < 0.001 ) {
        
            return mix( At(a,y:b) ,b: At(a,y:b+1) , f: rz )
        }
        
        if( rx < rz )
        {
            
            let w1 = rz*( At(a,y:b+1) - At(a,y:b) ) + At(a,y:b)
            let w2 = rz*( At(a+1,y:b+1) - At(a,y:b) ) + At(a,y:b)
            
            return w1 + rx/rz*( w2 - w1 )
            
        }
        else
        {
            
            let w1 = rx*( At(a+1,y:b) - At(a,y:b) ) + At(a,y:b)
            let w2 = rx*( At(a+1,y:b+1) - At(a,y:b) ) + At(a,y:b)
            
            return w1 + rz/rx*( w2 - w1 )
        }
        
    }
    
    func GetNormal(x:Float32, z:Float32) -> Vector3 {
    
        let a = Int(x)
        let b = Int(z)
        var v = Vector3(x:0.0, y:1.0, z:0.0)
        
        if( a < 0 || b < 0 || a > w-1 || b > h-1 ) {
        
           return v
        }
    
        var w1:Float32 = 0, w2:Float32 = 0
    
        var rx = x
        var rz = z
        
        rx -= Float32(a)
        rz -= Float32(b)
        
        w1 = z * ( normAt(a,y:b+1,d:0) - normAt(a,y:b,d:0) ) + normAt(a,y:b,d:0)
        w2 = z * ( normAt(a+1,y:b+1,d:0) - normAt(a+1,y:b,d:0) ) + normAt(a+1,y:b,d:0)
        
        v.x =  w1 + x*( w2 - w1 )
        
        w1 = z * ( normAt(a,y:b+1,d:1) - normAt(a,y:b,d:1) ) + normAt(a,y:b,d:1)
        w2 = z * ( normAt(a+1,y:b+1,d:1) - normAt(a+1,y:b,d:1) ) + normAt(a+1,y:b,d:1)
        
        v.y =  w1 + x*( w2 - w1 )
        
        w1 = z * ( normAt(a,y:b+1,d:2) - normAt(a,y:b,d:2) ) + normAt(a,y:b,d:2)
        w2 = z * ( normAt(a+1,y:b+1,d:2) - normAt(a+1,y:b,d:2) ) + normAt(a+1,y:b,d:2)
        
        v.z =  w1 + x*( w2 - w1 )

        v.normalize()
        
        return v
    }

}
