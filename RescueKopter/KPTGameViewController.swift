//
//  GameViewController.swift
//  RescueKopter
//
//  Created by Marcin Pędzimąż on 15.11.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit
import Metal
import QuartzCore

let maxFramesToBuffer = 3

struct sunStructure {
    
    var sunVector = Vector3()
    var sunColor = Vector3()
}

struct matrixStructure {
    
    var projMatrix = Matrix4x4()
    var viewMatrix = Matrix4x4()
    var normalMatrix = Matrix4x4()
}

class KPTGameViewController: UIViewController {
    
    let device = { MTLCreateSystemDefaultDevice() }()
    let metalLayer = { CAMetalLayer() }()
    
    var commandQueue: MTLCommandQueue! = nil
    var timer: CADisplayLink! = nil
    var pipelineState: MTLRenderPipelineState! = nil
    
    let inflightSemaphore = dispatch_semaphore_create(maxFramesToBuffer)
   
    //logic stuff
    internal var previousUpdateTime : CFTimeInterval = 0.0
    internal var delta : CFTimeInterval = 0.0
    
    var defaultLibrary: MTLLibrary! = nil
    
    //vector for viewMatrix
    var eyeVec = Vector3(x: 0.0,y: 2.0,z: 3.0)
    var dirVec = Vector3(x: 0.0,y: -0.234083,z: -0.9)
    var upVec = Vector3(x: 0, y: 1, z: 0)
    
    var loadedModels =  [KPTModel]()
    
    //sun info
    var sunPosition = Vector3(x: 5.316387,y: -2.408824,z: 0)
    
    var orangeColor = Vector3(x: 1.0, y: 0.5, z: 0.0)
    var yellowColor = Vector3(x: 1.0, y: 1.0, z: 0.8)
    
    //MARK: Render states
    var pipelineStates = [String : MTLRenderPipelineState]()
    
    //MARK: uniform data
    var sunBuffer: MTLBuffer! = nil
    var cameraMatrix: Matrix4x4 = Matrix4x4()
    
    var sunData = sunStructure()
    var matrixData = matrixStructure()
    
    var inverted = Matrix33()
    var baseStiencilState: MTLDepthStencilState! = nil
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        metalLayer.device = device
        metalLayer.pixelFormat = .BGRA8Unorm
        metalLayer.framebufferOnly = true
        
        self.resize()
        
        view.layer.addSublayer(metalLayer)
        view.opaque = true
        view.backgroundColor = nil
        
        commandQueue = device.newCommandQueue()
        commandQueue.label = "main command queue"
        
        //load data here:
        
        defaultLibrary = device.newDefaultLibrary()
        
        KPTSingletonFactory<KPTModelManager>.sharedInstance()
        KPTSingletonFactory<KPTTextureManager>.sharedInstance()
        
        //generate shaders and descriptors
        
        preparePipelineStates()
        
        //set matrix
        
        var aspect = Float32(view.frame.size.width/view.frame.size.height)
        matrixData.projMatrix = matrix44MakePerspective(degToRad(60), aspect, 0.01, 15000)
        
        //set unifor buffers
        
        sunBuffer = device.newBufferWithBytes(&sunData, length: sizeof(sunStructure), options: nil)
        
        loadGameData()
        
        timer = CADisplayLink(target: self, selector: Selector("renderLoop"))
        timer.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }

    func loadGameData() {
    
        var skyboxSphere = KPTSingletonFactory<KPTModelManager>.sharedInstance().loadModel("sphere", device: device)
        
        if let skyboxSphere = skyboxSphere {
            
            skyboxSphere.modelScale = 5000
            skyboxSphere.modelMatrix.t = Vector3()
            skyboxSphere.modelMatrix.M.rotY(0)
            
            //no back culling at all is skybox!
            skyboxSphere.setCullModeForMesh(0, mode: .None)
            skyboxSphere.setPipelineState(0, name: "skybox")
            
            var skyboxTex = KPTSingletonFactory<KPTTextureManager>.sharedInstance().loadCubeTexture("skybox", device: device)
            
            if let skyboxTex = skyboxTex {
                
                skyboxSphere.setTexture(0, texture: skyboxTex)
            }
            
            loadedModels.append(skyboxSphere)
        }

        var gameMap = KPTMapModel()
            gameMap.load("heightmap", device: device)
        
        loadedModels.append(gameMap)
    }
    
    func preparePipelineStates() {
    
        var desc = MTLDepthStencilDescriptor()
        desc.depthWriteEnabled = true;
        desc.depthCompareFunction = .LessEqual;
        baseStiencilState = device.newDepthStencilStateWithDescriptor(desc)
    
        //create all pipeline states for shaders
        var pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        var pipelineError : NSError?
        var fragmentProgram: MTLFunction?
        var vertexProgram: MTLFunction?
        
        
        //BASIC SHADER
        fragmentProgram = defaultLibrary?.newFunctionWithName("basicRenderFragment")
        vertexProgram = defaultLibrary?.newFunctionWithName("basicRenderVertex")
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        
        
        var basicState = device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor, error: &pipelineError)
        
        if (basicState == nil) {
            println("Failed to create pipeline state, error \(pipelineError)")
        }
        
        pipelineStates["basic"] = basicState
        
        //SKYBOX SHADER
        
        fragmentProgram = defaultLibrary?.newFunctionWithName("skyboxFragment")
        vertexProgram = defaultLibrary?.newFunctionWithName("skyboxVertex")
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        
        basicState = device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor, error: &pipelineError)
        
        if (basicState == nil) {
            println("Failed to create pipeline state, error \(pipelineError)")
        }
        
        pipelineStates["skybox"] = basicState
        
    }
    
    override func prefersStatusBarHidden() -> Bool {
        
        return false
    }
    
    override func viewDidLayoutSubviews() {
        
        self.resize()
    }
    
    func resize() {
        
        if (view.window == nil) {
            return
        }
        
        let window = view.window!
        let nativeScale = window.screen.nativeScale
        view.contentScaleFactor = nativeScale
        metalLayer.frame = view.layer.frame
        
        var drawableSize = view.bounds.size
        drawableSize.width = drawableSize.width * CGFloat(view.contentScaleFactor)
        drawableSize.height = drawableSize.height * CGFloat(view.contentScaleFactor)
        
        metalLayer.drawableSize = drawableSize
    }
    
    deinit {
        
        timer.invalidate()
    }
    
    func renderLoop() {
        
        autoreleasepool {
            self.render()
        }
    }
    
    func render() {
        
        dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER)
        
        self.update()
        
        let commandBuffer = commandQueue.commandBuffer()
        commandBuffer.label = "Frame command buffer"
        
        let drawable = metalLayer.nextDrawable()
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .Clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .Store
        
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)!
        renderEncoder.label = "render encoder"
        renderEncoder.setFrontFacingWinding(.CounterClockwise)
        renderEncoder.setDepthStencilState(baseStiencilState)
        
        renderEncoder.setVertexBuffer(sunBuffer, offset: 0, atIndex: 2)
        
        //game rendering here
        
        var cameraViewMatrix = Matrix34(initialize: false)
        cameraViewMatrix.setColumnMajor44(cameraMatrix)
        
        for model in loadedModels {
            
            //calcualte real model view matrix
            var modelViewMatrix = cameraViewMatrix * (model.modelMatrix * model.modelScale)
            
            var normalMatrix = Matrix33(other: modelViewMatrix.M)
            
            if modelViewMatrix.M.getInverse(&inverted) == true {
                
                normalMatrix.setTransposed(inverted)
            }
            
            //set updated buffer info
            modelViewMatrix.getColumnMajor44(&matrixData.viewMatrix)
            
            var normal4x4 = Matrix34(rot: normalMatrix, trans: Vector3(x: 0, y: 0, z: 0))
            normal4x4.getColumnMajor44(&matrixData.normalMatrix)
            
            //cannot modify single value
            var matrices = UnsafeMutablePointer<matrixStructure>(model.matrixBuffer.contents())
            matrices.memory = matrixData
            
            renderEncoder.setVertexBuffer(model.matrixBuffer, offset: 0, atIndex: 1)
            
            model.render(renderEncoder, states: pipelineStates, shadowPass: false)
        }
        
        renderEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
            if let strongSelf = self {
                dispatch_semaphore_signal(strongSelf.inflightSemaphore)
            }
            return
        }
    
        commandBuffer.presentDrawable(drawable)
        commandBuffer.commit()
    }
    
    func update() {
        
        delta = timer.timestamp - self.previousUpdateTime
        previousUpdateTime = timer.timestamp
        
        if delta > 0.3 {
            delta = 0.3
        }
        
        //update lookAt matrix
        cameraMatrix = matrix44MakeLookAt(eyeVec, eyeVec+dirVec, upVec)
        
        //udpate sun position and color
        
        sunPosition.y += Float32(delta) * 0.05
        sunPosition.x += Float32(delta) * 0.05
        
        sunData.sunVector = Vector3(x: -cosf(sunPosition.x) * sinf(sunPosition.y),
                                    y: -cosf(sunPosition.y),
                                    z: -sinf(sunPosition.x) * sinf(sunPosition.y))
        
        var sun_cosy = sunData.sunVector.y
        var factor = 0.25 + sun_cosy * 0.75
        
        sunData.sunColor = ((orangeColor * (1.0 - factor)) + (yellowColor * factor))
        
        memcpy(sunBuffer.contents(), &sunData, UInt(sizeof(sunStructure)))
        
        //update kopter logic here:
        
        
    }
}