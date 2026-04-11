//
//  Contrast.metal
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

#include <metal_stdlib>
using namespace metal;

struct ContrastUniforms {
    float factor;
};

kernel void adjustContrast(
                           texture2d<float, access::read>  inTexture  [[texture(0)]],
                           texture2d<float, access::write> outTexture [[texture(1)]],
                           constant ContrastUniforms& uniforms          [[buffer(0)]],
                           uint2 gid                                  [[thread_position_in_grid]])
{
    float factor = uniforms.factor;
    float4 color = inTexture.read(gid);
    
    float multiplier = (factor >= 0)
    ? 1.0 + (factor / 100.0)
    : 1.0 / (1.0 + (-factor / 100.0));
    
    float4 adjusted = (color - 0.5) * multiplier + 0.5;
    
    outTexture.write(saturate(adjusted), gid);
}
