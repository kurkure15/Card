//
//  AnimatedGradientView.swift
//  Card
//
//  Metal-based animated gradient inspired by Any Distance
//  Supports dynamic colors extracted from images
//

import UIKit
import MetalKit
import SwiftUI

// MARK: - Metal Color Struct (matches shader)

/// Must match the DynamicColors struct in the Metal shader
struct DynamicColors {
    var color1: SIMD3<Float>
    var color2: SIMD3<Float>
    var color3: SIMD3<Float>
    var color4: SIMD3<Float>

    /// Create from UIColors
    init(colors: [UIColor]) {
        func toSIMD(_ color: UIColor) -> SIMD3<Float> {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return SIMD3<Float>(Float(r), Float(g), Float(b))
        }

        // Ensure we have at least 4 colors, pad with defaults if needed
        let paddedColors = colors + Array(repeating: UIColor.black, count: max(0, 4 - colors.count))

        self.color1 = toSIMD(paddedColors[0])
        self.color2 = toSIMD(paddedColors[1])
        self.color3 = toSIMD(paddedColors[2])
        self.color4 = toSIMD(paddedColors[3])
    }

    /// Default dark purple palette
    static let defaultDark = DynamicColors(colors: [
        UIColor(red: 45/255, green: 20/255, blue: 60/255, alpha: 1),
        UIColor(red: 80/255, green: 40/255, blue: 90/255, alpha: 1),
        UIColor(red: 20/255, green: 10/255, blue: 30/255, alpha: 1),
        UIColor(red: 60/255, green: 30/255, blue: 70/255, alpha: 1)
    ])
}

// MARK: - SwiftUI Wrapper

/// SwiftUI wrapper for the Metal gradient animation
struct AnimatedGradientView: UIViewRepresentable {
    /// Dynamic colors for the gradient (extracted from image)
    var colors: DynamicColors

    /// Initialize with default dark colors
    init() {
        self.colors = .defaultDark
    }

    /// Initialize with custom colors
    init(colors: DynamicColors) {
        self.colors = colors
    }

    /// Initialize with UIColor array
    init(uiColors: [UIColor]) {
        self.colors = DynamicColors(colors: uiColors)
    }

    /// Initialize with ImageColors (from extractor)
    init(imageColors: ImageColors) {
        self.colors = DynamicColors(colors: imageColors.asArray)
    }

    func makeUIView(context: Context) -> GradientAnimationMTKView {
        let view = GradientAnimationMTKView()
        view.dynamicColors = colors
        return view
    }

    func updateUIView(_ uiView: GradientAnimationMTKView, context: Context) {
        // Smoothly transition to new colors
        uiView.setColors(colors, animated: true)
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

    /// Current colors being rendered
    var dynamicColors: DynamicColors = .defaultDark

    /// Target colors for animation
    private var targetColors: DynamicColors = .defaultDark

    /// Color transition progress (0-1)
    private var colorTransitionProgress: Float = 1.0

    /// Previous colors for interpolation
    private var previousColors: DynamicColors = .defaultDark

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

    /// Set new colors with optional animation
    func setColors(_ colors: DynamicColors, animated: Bool) {
        if animated {
            previousColors = dynamicColors
            targetColors = colors
            colorTransitionProgress = 0.0
        } else {
            dynamicColors = colors
            targetColors = colors
            colorTransitionProgress = 1.0
        }
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

    /// Interpolate between two SIMD3 values
    private func lerp(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
        return a + (b - a) * t
    }

    /// Get interpolated colors for smooth transitions
    private func getInterpolatedColors() -> DynamicColors {
        let t = colorTransitionProgress
        return DynamicColors(colors: [
            UIColor(
                red: CGFloat(lerp(previousColors.color1, targetColors.color1, t).x),
                green: CGFloat(lerp(previousColors.color1, targetColors.color1, t).y),
                blue: CGFloat(lerp(previousColors.color1, targetColors.color1, t).z),
                alpha: 1
            ),
            UIColor(
                red: CGFloat(lerp(previousColors.color2, targetColors.color2, t).x),
                green: CGFloat(lerp(previousColors.color2, targetColors.color2, t).y),
                blue: CGFloat(lerp(previousColors.color2, targetColors.color2, t).z),
                alpha: 1
            ),
            UIColor(
                red: CGFloat(lerp(previousColors.color3, targetColors.color3, t).x),
                green: CGFloat(lerp(previousColors.color3, targetColors.color3, t).y),
                blue: CGFloat(lerp(previousColors.color3, targetColors.color3, t).z),
                alpha: 1
            ),
            UIColor(
                red: CGFloat(lerp(previousColors.color4, targetColors.color4, t).x),
                green: CGFloat(lerp(previousColors.color4, targetColors.color4, t).y),
                blue: CGFloat(lerp(previousColors.color4, targetColors.color4, t).z),
                alpha: 1
            )
        ])
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

        // Update color transition
        if colorTransitionProgress < 1.0 {
            colorTransitionProgress += 0.02 // ~0.8 second transition at 60fps
            colorTransitionProgress = min(colorTransitionProgress, 1.0)
            dynamicColors = getInterpolatedColors()
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

        // Pass dynamic colors to fragment shader
        var colors = dynamicColors
        renderEncoder.setFragmentBytes(&colors, length: MemoryLayout<DynamicColors>.stride, index: 0)

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
    AnimatedGradientView()
        .ignoresSafeArea()
}
