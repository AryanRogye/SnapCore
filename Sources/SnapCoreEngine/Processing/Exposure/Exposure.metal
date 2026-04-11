//
//  Exposure.metal
//  SnapCore
//
//  Created by Aryan Rogye on 4/11/26.
//

#include <metal_stdlib>
#include "../KernelNxN.metalh"
using namespace metal;

struct ExposureUniforms {
    float factor;
};

kernel void apply_exposure(
                           texture2d<float, access::read>  inTexture  [[texture(0)]],
                           texture2d<float, access::write> outTexture [[texture(1)]],
                           constant ExposureUniforms& uniforms [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]
                           ) {
    float factor = uniforms.factor;
    float4 color = inTexture.read(gid);
    
    float multiplier = (factor >= 0)
    ? 1.0 + (factor / 100.0)
    : 1.0 / (1.0 + (-factor / 100.0));
    
    color.rgb *= multiplier;
    
    outTexture.write(color, gid);
}
