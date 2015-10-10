//
//  KPTModelManager.swift
//  RescueKopter
//
//  Created by Marcin Pędzimąż on 15.11.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit
import Metal

class KPTModelManager {
   
    static let sharedInstance = KPTModelManager()
    
    private var modelsCache = [String: KPTModel]()
    
    required init() {
        
    }
    
    func loadModel(name: String!, device: MTLDevice!) -> KPTModel? {
        
        let model = modelsCache[name]
        
        if let model = model {
            
            return model
        }
        
        let loadedModel = KPTModel()
        
        let info = loadedModel.load(name, device: device)
        
        if info.loaded == false {
            
            print("Error while loadin model: \(info.error!)");
            return nil
        }
        
        modelsCache[name] = loadedModel
        
        return loadedModel
    }
}
