//
//  Generic.swift
//  RescueKopter
//
//  Created by Marcin Pędzimąż on 15.11.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit

func mix(a: Float32, b: Float32, f: Float32) -> Float32 {
    
    return a + (b - a) * f
}
