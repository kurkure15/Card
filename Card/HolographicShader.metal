//
//  HolographicShader.metal
//  Card
//
//  Holographic sticker effect with noise-based warping
//  and spectral palette mapping for iridescent rainbow gloss
//

#include <metal_stdlib>
using namespace metal;

struct HoloVertexIn {
    float2 position;
};

struct HoloVertexOut {
    float4 position [[position]];
    float2 uv;
};

struct HoloUniforms {
    float2 dragOffset;   // normalized drag position (-1 to 1)
    float time;
    float2 viewSize;
};

vertex HoloVertexOut holo_vertex(
    const device HoloVertexIn* vertices [[buffer(0)]],
    constant HoloUniforms &uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    HoloVertexOut out;
    out.position = float4(vertices[vid].position, 0.0, 1.0);
    // Map from clip space (-1,1) to UV (0,1)
    out.uv = (vertices[vid].position + 1.0) * 0.5;
    out.uv.y = 1.0 - out.uv.y; // flip Y
    return out;
}

// Simple 2D noise
float holo_hash(float2 p) {
    float h = dot(p, float2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

float holo_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep

    float a = holo_hash(i);
    float b = holo_hash(i + float2(1.0, 0.0));
    float c = holo_hash(i + float2(0.0, 1.0));
    float d = holo_hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal noise for organic warping
float holo_fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * holo_noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Spectral palette - maps a value 0-1 to rainbow colors
float3 spectral_palette(float t) {
    // HSV-like rainbow with smooth transitions
    float3 a = float3(0.5, 0.5, 0.5);
    float3 b = float3(0.5, 0.5, 0.5);
    float3 c = float3(1.0, 1.0, 1.0);
    float3 d = float3(0.00, 0.33, 0.67);
    return a + b * cos(6.28318 * (c * t + d));
}

fragment float4 holo_fragment(
    HoloVertexOut in [[stage_in]],
    constant HoloUniforms &uniforms [[buffer(0)]],
    texture2d<float> photoTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    float2 uv = in.uv;
    float2 drag = uniforms.dragOffset;
    float time = uniforms.time;

    // Sample the photo
    float4 photo = photoTexture.sample(textureSampler, uv);

    // Create noise-based warp field influenced by drag
    float2 warpUV = uv * 4.0 + drag * 2.0 + time * 0.1;
    float noiseVal = holo_fbm(warpUV);

    // Create angle based on noise + UV position + drag
    float angle = noiseVal * 6.28 + dot(uv - 0.5, drag + 0.5) * 8.0;

    // Spectral color from the warped angle
    float3 rainbow = spectral_palette(angle * 0.15 + noiseVal * 0.5 + time * 0.05);

    // Gloss intensity - stronger near the drag point, with noise variation
    float2 toCenter = uv - 0.5;
    float dragInfluence = 1.0 - length(toCenter - drag * 0.3) * 1.2;
    dragInfluence = clamp(dragInfluence, 0.0, 1.0);

    // Fresnel-like edge glow
    float fresnel = pow(1.0 - abs(dot(normalize(toCenter), float2(0.0, 1.0))), 2.0);

    // Combine gloss intensity
    float glossIntensity = (dragInfluence * 0.6 + fresnel * 0.3 + noiseVal * 0.2) * 0.45;

    // Blend rainbow gloss over photo
    float3 result = mix(photo.rgb, rainbow, glossIntensity);

    // Add subtle highlight streaks
    float streak = pow(max(0.0, sin(angle * 3.0 + drag.x * 10.0)), 8.0) * 0.15;
    result += streak;

    return float4(result, photo.a);
}
