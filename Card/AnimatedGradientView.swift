//
//  AnimatedGradientView.swift
//  Card
//
//  Metal-based animated gradient inspired by Any Distance
//

import UIKit
import MetalKit
import SwiftUI

// MARK: - SwiftUI Wrapper

/// SwiftUI wrapper for the Metal gradient animation
struct AnimatedGradientView: UIViewRepresentable {
    /// Color palette index (0-4)
    /// 0: Dark moody reds/oranges
    /// 1: Ocean blues
    /// 2: Teal/cyan
    /// 3: Vibrant neon
    /// 4: Dark purple (default for Card app)
    var colorPalette: Int = 4

    func makeUIView(context: Context) -> GradientAnimationMTKView {
        let view = GradientAnimationMTKView()
        view.page = colorPalette
        return view
    }

    func updateUIView(_ uiView: GradientAnimationMTKView, context: Context) {
        uiView.page = colorPalette
    }
}

// MARK: - Metal View

/// UIView that renders animated gradients using Metal shaders
class GradientAnimationMTKView: UIView {
    private var mtkView: MTKView?
    private let device = MTLCreateSystemDefaultDevice()
    private var pipelineState: MTLRenderPipelineState?
    private var commandQueue: MTLCommandQueue?
    private var vertexBuffer: MTLBuffer?

    private var time: Float = 0.0
    var page: Int = 0

    private lazy var viewSize: [Float] = {
        return [
            Float(UIScreen.main.bounds.width * UIScreen.main.scale),
            Float(UIScreen.main.bounds.height * UIScreen.main.scale)
        ]
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupMetal()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMetal()
    }

    private func setupMetal() {
        guard let device = device else {
            print("Metal is not supported on this device")
            return
        }

        // Create shader library
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create Metal library")
            return
        }

        // Get shader functions
        guard let vertexFunction = library.makeFunction(name: "gradient_animation_vertex"),
              let fragmentFunction = library.makeFunction(name: "gradient_animation_fragment") else {
            print("Failed to find shader functions")
            return
        }

        // Create pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Create vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 3
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        // Create pipeline state
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
            return
        }

        // Create command queue
        commandQueue = device.makeCommandQueue()

        // Create vertex buffer (two triangles forming a quad)
        let vertexData: [Float] = [
            1, 1, 0,
            -1, -1, 0,
            -1, 1, 0,
            1, 1, 0,
            -1, -1, 0,
            1, -1, 0
        ]
        let dataSize = vertexData.count * MemoryLayout<Float>.size
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])

        // Create and configure MTKView
        mtkView = MTKView(frame: bounds, device: device)
        mtkView?.delegate = self
        mtkView?.preferredFramesPerSecond = 60
        mtkView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if let mtkView = mtkView {
            addSubview(mtkView)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        mtkView?.frame = bounds
        viewSize = [
            Float(bounds.width * UIScreen.main.scale),
            Float(bounds.height * UIScreen.main.scale)
        ]
    }
}

// MARK: - MTKViewDelegate

extension GradientAnimationMTKView: MTKViewDelegate {
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let pipelineState = pipelineState,
              let vertexBuffer = vertexBuffer else {
            return
        }

        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        descriptor.colorAttachments[0].texture = drawable.texture
        descriptor.colorAttachments[0].loadAction = .clear

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        // Update time (controls animation speed)
        time += 1.5 / Float(view.preferredFramesPerSecond)

        // Set up render encoder
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&time, length: MemoryLayout<Float>.stride, index: 1)
        renderEncoder.setVertexBytes(&viewSize, length: MemoryLayout<Float>.stride * viewSize.count, index: 2)
        renderEncoder.setVertexBytes(&page, length: MemoryLayout<Int>.stride, index: 3)

        // Draw
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewSize = [
            Float(size.width),
            Float(size.height)
        ]
    }
}

// MARK: - Preview

#Preview {
    AnimatedGradientView(colorPalette: 4)
        .ignoresSafeArea()
}
