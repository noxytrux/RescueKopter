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
import CoreMotion

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
    
    @IBOutlet weak var loadingLabel: UILabel!
    let device = { MTLCreateSystemDefaultDevice() }()
    let metalLayer = { CAMetalLayer() }()
    
    var commandQueue: MTLCommandQueue! = nil
    var timer: CADisplayLink! = nil
    var pipelineState: MTLRenderPipelineState! = nil
    
    let inflightSemaphore = dispatch_semaphore_create(maxFramesToBuffer)
   
    //logic stuff
    internal var previousUpdateTime : CFTimeInterval = 0.0
    internal var delta : CFTimeInterval = 0.0
    internal var accumulator:CFTimeInterval = 0.0
    internal let fixedDelta = 0.03
    
    var defaultLibrary: MTLLibrary! = nil
    
    //vector for viewMatrix
    var eyeVec = Vector3(x: 0.0,y: 2,z: 3.0)
    var dirVec = Vector3(x: 0.0,y: -0.23,z: -1.0)
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
    var upRotation: Float = 0
    var modelDirection: Float = 0
    
    //MOTION
    
    let manager = CMMotionManager()
    let queue = NSOperationQueue()

    weak var kopter:KPTModel? = nil
    weak var heightMap:KPTHeightMap? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        metalLayer.device = device
        metalLayer.pixelFormat = .BGRA8Unorm
        metalLayer.framebufferOnly = true
        
        self.resize()
        
        view.layer.addSublayer(metalLayer)
        view.opaque = true
        view.backgroundColor = UIColor.whiteColor()
        
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

        if manager.deviceMotionAvailable {
            
            manager.deviceMotionUpdateInterval = 0.01
        
            manager.startDeviceMotionUpdatesToQueue(queue) {
                (motion:CMDeviceMotion!, error:NSError!) -> Void in
                
                let attitude:CMAttitude = motion.attitude
                
                self.upRotation = Float(atan2(Double(radToDeg(Float32(attitude.pitch))), Double(radToDeg(Float32(attitude.roll)))))
            }
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
            
            self.loadGameData()
       
            dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                
                self.loadingLabel.hidden = true
                self.view.backgroundColor = nil
                
                
                self.timer = CADisplayLink(target: self, selector: Selector("renderLoop"))
                self.timer.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
            })
        })
        
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
        
        var helicopter = KPTSingletonFactory<KPTModelManager>.sharedInstance().loadModel("helicopter", device: device)
        
        if let helicopter = helicopter {
        
            helicopter.modelScale = 1.0
            helicopter.modelMatrix.t = Vector3(x:0,y:34,z:-3)
            
            var rotX = Matrix33()
                rotX.rotX(Float(M_PI_2))
            
            var rotZ = Matrix33()
                rotZ.rotY(Float(M_PI))
            
            helicopter.modelMatrix.M = rotX * rotZ
            
            loadedModels.append(helicopter)
            
            kopter = helicopter
        }

        var gameMap = KPTMapModel()
            gameMap.load("heightmap", device: device)
        
        heightMap = gameMap.heightMap
        
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
        
        return true
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
        
        //update gyro:
        var uprotationValue = min(max(upRotation, -0.7), 0.7)
        
        var realUp = upVec
        var rotationMat = Matrix33()
        rotationMat.rotZ(uprotationValue)
        
        rotationMat.multiply(upVec, dst: &realUp)

        accumulator += delta
        
        while (accumulator > fixedDelta) {
        
            calculatePhysic()
            accumulator -= fixedDelta
        }
        
        //update lookAt matrix
        cameraMatrix = matrix44MakeLookAt(eyeVec, eyeVec+dirVec, realUp)
        
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
        
    }
    
    func calculatePhysic() {
    
        //update kopter logic
        if let kopter = kopter {
            
            var kopterRotation = min(max(upRotation, -0.4), 0.4)
            modelDirection += kopterRotation * 0.5
            
            var rotX = Matrix33()
            rotX.rotX(Float(M_PI_2))
            
            var rotY = Matrix33()
            rotY.rotY(Float(M_PI))
            
            var rotK1 = Matrix33()
            rotK1.rotZ(modelDirection)
            
            var rotK2 = Matrix33()
            rotK2.rotY(kopterRotation)
            
            kopter.modelMatrix.M = rotX * rotY * rotK1 * rotK2
            
            //flying
            var speed:Float = 9.0
            var pos = Vector3(x: Float32(sin(modelDirection) * speed * Float(fixedDelta)), y: 0.0, z: Float32(cos(modelDirection) * speed * Float(fixedDelta)))
            var dist = Vector3(x: Float32(sin(modelDirection) * speed), y: 0.0, z: Float32(cos(modelDirection) * speed))
            
            eyeVec = kopter.modelMatrix.t + dist
            eyeVec.y += 2
            
            dirVec = eyeVec - kopter.modelMatrix.t
            dirVec.normalize()
            dirVec.setNegative()
            
            dirVec.y = -0.23
            
            kopter.modelMatrix.t -= pos
            var px: Float32 = kopter.modelMatrix.t.x + 256.0
            var pz: Float32 = kopter.modelMatrix.t.z + 256.0
            
            kopter.modelMatrix.t.y = fabs(heightMap!.GetHeight(px/2.0, z: pz/2.0) / 8.0 ) + 10.0
        }

    }
}