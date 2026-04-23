//
//  Saturation.metal
//  SnapCore
//
//  Created by Aryan Rogye on 4/23/26.
//

#include <metal_stdlib>
using namespace metal;

struct SaturationUniforms {
    float factor;
};

kernel void adjust_saturation(
                              texture2d<float, access::read>  inTexture  [[texture(0)]],
                              texture2d<float, access::write> outTexture [[texture(1)]],
                              constant SaturationUniforms& uniforms [[buffer(0)]],
                              uint2 gid [[thread_position_in_grid]]
                              ) {
    uint width  = inTexture.get_width();
    uint height = inTexture.get_height();
    
    if (gid.x >= width || gid.y >= height) return;
    
    float4 color = inTexture.read(gid);
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float saturation = max(0.0, 1.0 + (uniforms.factor / 100.0));
    float3 adjusted = mix(float3(luminance), color.rgb, saturation);
    
    outTexture.write(float4(clamp(adjusted, 0.0, 1.0), color.a), gid);
}
