//
//  sharpen.metal
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

#include <metal_stdlib>
#include "../KernelNxN.metalh"
using namespace metal;

struct SharpenUniforms {
    float sharpness;
};


kernel void sharpen_kernel(
                           texture2d<float, access::read>  inTexture  [[texture(0)]],
                           texture2d<float, access::write> outTexture [[texture(1)]],
                           constant SharpenUniforms& uniforms [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]
                           ) {
    
    float sharpness = uniforms.sharpness;
    
    uint width  = inTexture.get_width();
    uint height = inTexture.get_height();
    
    if (gid.x >= width || gid.y >= height) return;
    
    KernelNxN<3> k;
    k.load(inTexture, gid, width, height);
    
    float weights[3][3] = {
        { -0.0023, -0.0432,            -0.0023 },
        { -0.0432, sharpness - 0.8180, -0.0432 },
        { -0.0023, -0.0432,            -0.0023 }
    };
    float4 result = k.convolve(weights);
    result.a = k.v[1][1].a;
    
    outTexture.write(clamp(result, 0.0, 1.0), gid);
}
