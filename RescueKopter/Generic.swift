//
//  Generic.swift
//  RescueKopter
//
//  Created by Marcin Pędzimąż on 15.11.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit

protocol KPTSingletonProtocol
{
    class func className() -> String
    
    init()
}

private var singleton_map: [String : KPTSingletonProtocol] = [String : KPTSingletonProtocol]()
private var singleton_queue: dispatch_queue_t = dispatch_queue_create("com.kopter.singletonfactory", DISPATCH_QUEUE_SERIAL)

struct KPTSingletonFactory<T: KPTSingletonProtocol>
{
    static func sharedInstance() -> T
    {
        var dev: T?
        
        dispatch_sync(singleton_queue) {
            
            let identifier = T.className()
            var singleton: T? = singleton_map[identifier] as? T
            
            if singleton == nil {
                
                singleton = T()
                singleton_map.updateValue(singleton!, forKey: identifier)
            }
            
            dev = singleton
        }
        
        return dev!
    }
}

func mix(a: Float32, b: Float32, f: Float32) -> Float32 {
    
    return a + (b - a) * f
}
