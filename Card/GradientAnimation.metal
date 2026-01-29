//
//  GradientAnimation.metal
//  Card
//
//  Adapted from Any Distance's gradient animation
//  Modified to support dynamic colors from images
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position;
};

struct VertexOut {
    float4 position [[position]];
    float time;
    float2 viewSize;
};

/// Custom colors passed from Swift (4 colors * 3 components = 12 floats)
struct DynamicColors {
    float3 color1;
    float3 color2;
    float3 color3;
    float3 color4;
};

/// Noise functions for organic movement
float noise1(float seed1, float seed2){
    return(
           fract(seed1+12.34567*
                 fract(100.*(abs(seed1*0.91)+seed2+94.68)*
                       fract((abs(seed2*0.41)+45.46)*
                             fract((abs(seed2)+757.21)*
                                   fract(seed1*0.0171))))))
    * 1.0038 - 0.00185;
}

float noise2(float seed1, float seed2, float seed3){
    float buff1 = abs(seed1+100.81) + 1000.3;
    float buff2 = abs(seed2+100.45) + 1000.2;
    float buff3 = abs(noise1(seed1, seed2)+seed3) + 1000.1;
    buff1 = (buff3*fract(buff2*fract(buff1*fract(buff2*0.146))));
    buff2 = (buff2*fract(buff2*fract(buff1+buff2*fract(buff3*0.52))));
    buff1 = noise1(buff1, buff2);
    return(buff1);
}

float noise3(float seed1, float seed2, float seed3) {
    float buff1 = abs(seed1+100.813) + 1000.314;
    float buff2 = abs(seed2+100.453) + 1000.213;
    float buff3 = abs(noise1(buff2, buff1)+seed3) + 1000.17;
    buff1 = (buff3*fract(buff2*fract(buff1*fract(buff2*0.14619))));
    buff2 = (buff2*fract(buff2*fract(buff1+buff2*fract(buff3*0.5215))));
    buff1 = noise2(noise1(seed2,buff1), noise1(seed1,buff2), noise1(seed3,buff3));
    return(buff1);
}

/// Passthrough vertex shader
vertex VertexOut gradient_animation_vertex(const device packed_float3* in [[ buffer(0) ]],
                                           constant float &time [[buffer(1)]],
                                           const device packed_float2* viewSize [[buffer(2)]],
                                           unsigned int vid [[ vertex_id ]]) {
    VertexOut out;
    out.position = float4(in[vid], 1);
    out.time = time;
    out.viewSize = float2(viewSize->x, viewSize->y);
    return out;
}

/// Fragment shader for gradient animation with dynamic colors
fragment float4 gradient_animation_fragment(VertexOut in [[stage_in]],
                                            constant DynamicColors &colors [[buffer(0)]]) {
    float2 st = in.position.xy/in.viewSize.xy;
    st = float2(tan(st.x), sin(st.y));

    st.x += (sin(in.time/2.1)+2.0)*0.12*sin(sin(st.y*st.x+in.time/6.0)*8.2);
    st.y -= (cos(in.time/1.73)+2.0)*0.12*cos(st.x*st.y*5.1-in.time/4.0);

    float3 bg = float3(0.0);

    // Use dynamic colors passed from Swift
    float3 color1 = colors.color1;
    float3 color2 = colors.color2;
    float3 color3 = colors.color3;
    float3 color4 = colors.color4;
    // Create a 5th color by mixing color1 and color3
    float3 color5 = mix(color1, color3, 0.5);

    float mixValue = smoothstep(0.0, 0.8, distance(st,float2(sin(in.time/5.0)+0.5,sin(in.time/6.1)+0.5)));
    float3 outColor = mix(color1,bg,mixValue);

    mixValue = smoothstep(0.1, 0.9, distance(st,float2(sin(in.time/3.94)+0.7,sin(in.time/4.2)-0.1)));
    outColor = mix(color2,outColor,mixValue);

    mixValue = smoothstep(0.1, 0.8, distance(st,float2(sin(in.time/3.43)+0.2,sin(in.time/3.2)+0.45)));
    outColor = mix(color3,outColor,mixValue);

    mixValue = smoothstep(0.14, 0.89, distance(st,float2(sin(in.time/5.4)-0.3,sin(in.time/5.7)+0.7)));
    outColor = mix(color4,outColor,mixValue);

    mixValue = smoothstep(0.01, 0.89, distance(st,float2(sin(in.time/9.5)+0.23,sin(in.time/3.95)+0.23)));
    outColor = mix(color5,outColor,mixValue);

    /// Second layer of blobs
    mixValue = smoothstep(0.01, 0.89, distance(st,float2(cos(in.time/8.5)/2.+0.13,sin(in.time/4.95)-0.23)));
    outColor = mix(color1,outColor,mixValue);

    mixValue = smoothstep(0.1, 0.9, distance(st,float2(cos(in.time/6.94)/2.+0.7,sin(in.time/4.112)+0.66)));
    outColor = mix(color2,outColor,mixValue);

    mixValue = smoothstep(0.1, 0.8, distance(st,float2(cos(in.time/4.43)/2.+0.2,sin(in.time/6.2)+0.85)));
    outColor = mix(color3,outColor,mixValue);

    mixValue = smoothstep(0.14, 0.89, distance(st,float2(cos(in.time/10.4)/2.-0.3,sin(in.time/5.7)+0.8)));
    outColor = mix(color4,outColor,mixValue);

    mixValue = smoothstep(0.01, 0.89, distance(st,float2(cos(in.time/4.5)/2.+0.63,sin(in.time/4.95)+0.93)));
    outColor = mix(color5,outColor,mixValue);

    // Add subtle noise
    float2 st_unwarped = in.position.xy/in.viewSize.xy;
    float3 noise = float3(noise3(st_unwarped.x*0.000001, st_unwarped.y*0.000001, in.time * 1e-15));
    outColor = (outColor * 0.85) - (noise * 0.1);

    return float4(outColor, 1.0);
}
