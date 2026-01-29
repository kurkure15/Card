//
//  HolographicStickerView.swift
//  Card
//
//  Holographic sticker effect that applies an iridescent rainbow gloss
//  over a photo, shifting based on device motion (gyroscope/accelerometer).
//  Uses Metal shader with noise-based warping and spectral palette mapping.
//

import SwiftUI
import MetalKit
import UIKit
import CoreMotion

// MARK: - SwiftUI Wrapper

struct HolographicStickerView: UIViewRepresentable {
    let imageName: String

    func makeUIView(context: Context) -> HolographicMTKView {
        let view = HolographicMTKView(imageName: imageName)
        return view
    }

    func updateUIView(_ uiView: HolographicMTKView, context: Context) {}
}

// MARK: - Uniforms (matches shader)

struct HoloUniforms {
    var dragOffset: SIMD2<Float>
    var time: Float
    var viewSize: SIMD2<Float>
}

// MARK: - Metal View

class HolographicMTKView: UIView, MTKViewDelegate {
    private var mtkView: MTKView?
    private let device = MTLCreateSystemDefaultDevice()
    private var pipelineState: MTLRenderPipelineState?
    private var commandQueue: MTLCommandQueue?
    private var vertexBuffer: MTLBuffer?
    private var texture: MTLTexture?
    private var samplerState: MTLSamplerState?

    private var time: Float = 0.0
    private var currentTiltOffset: SIMD2<Float> = .zero
    private var targetTiltOffset: SIMD2<Float> = .zero

    // CoreMotion
    private let motionManager = CMMotionManager()

    init(imageName: String) {
        super.init(frame: .zero)
        setupMetal()
        loadTexture(named: imageName)
        startMotionUpdates()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMetal()
        startMotionUpdates()
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }

    // MARK: - Device Motion

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let motion = motion else { return }
            // Use device attitude (pitch and roll) for the holographic offset
            // Pitch: tilting forward/backward, Roll: tilting left/right
            // Clamp to -1...1 range for the shader
            let roll = Float(motion.attitude.roll)   // left/right tilt
            let pitch = Float(motion.attitude.pitch)  // forward/backward tilt
            self?.targetTiltOffset = SIMD2<Float>(
                max(-1, min(1, roll * 1.5)),
                max(-1, min(1, (pitch - 0.5) * 1.5))  // offset pitch since phone is usually held at ~30 degrees
            )
        }
    }

    private func setupMetal() {
        guard let device = device else { return }

        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "holo_vertex"),
              let fragmentFunction = library.makeFunction(name: "holo_fragment") else {
            return
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        // Enable alpha blending
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 2
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Holographic pipeline error: \(error)")
            return
        }

        commandQueue = device.makeCommandQueue()

        // Full-screen quad (two triangles)
        let vertexData: [Float] = [
             1,  1,
            -1, -1,
            -1,  1,
             1,  1,
            -1, -1,
             1, -1
        ]
        vertexBuffer = device.makeBuffer(
            bytes: vertexData,
            length: vertexData.count * MemoryLayout<Float>.size,
            options: []
        )

        // Sampler
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)

        // MTKView
        mtkView = MTKView(frame: bounds, device: device)
        mtkView?.delegate = self
        mtkView?.preferredFramesPerSecond = 60
        mtkView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mtkView?.isOpaque = false
        mtkView?.layer.isOpaque = false
        mtkView?.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        if let mtkView = mtkView {
            addSubview(mtkView)
        }
    }

    private func loadTexture(named name: String) {
        guard let device = device,
              let image = UIImage(named: name)?.cgImage else { return }

        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .origin: MTKTextureLoader.Origin.topLeft,
            .SRGB: false
        ]

        do {
            texture = try textureLoader.newTexture(cgImage: image, options: options)
        } catch {
            print("Failed to load holographic texture: \(error)")
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        mtkView?.frame = bounds
    }

    // MARK: - MTKViewDelegate

    func draw(in view: MTKView) {
        // Smooth interpolation toward target tilt
        currentTiltOffset += (targetTiltOffset - currentTiltOffset) * 0.08

        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let pipelineState = pipelineState,
              let vertexBuffer = vertexBuffer,
              let texture = texture,
              let samplerState = samplerState else { return }

        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        descriptor.colorAttachments[0].loadAction = .clear

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        time += 1.0 / Float(view.preferredFramesPerSecond)

        var uniforms = HoloUniforms(
            dragOffset: currentTiltOffset,
            time: time,
            viewSize: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        )

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<HoloUniforms>.stride, index: 1)
        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<HoloUniforms>.stride, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
