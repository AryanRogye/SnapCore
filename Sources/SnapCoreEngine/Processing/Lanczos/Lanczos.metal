//
//  Lanczos.metal
//  SnapCore
//
//  Created by Aryan Rogye on 3/26/26.
//

#include <metal_stdlib>
#include "../KernelNxN.metalh"
using namespace metal;

struct LanczosUniforms {
    float scale;
    int kernelSize;
};

kernel void lanczos_upscale(
                            texture2d<float, access::read>  inTexture  [[texture(0)]],
                            texture2d<float, access::write> outTexture [[texture(1)]],
                            constant LanczosUniforms& uniforms [[buffer(0)]],
                            uint2 gid [[thread_position_in_grid]]
                            ) {
    uint outWidth  = outTexture.get_width();
    uint outHeight = outTexture.get_height();
    
    if (gid.x >= outWidth || gid.y >= outHeight) return;
    
    uint inWidth  = inTexture.get_width();
    uint inHeight = inTexture.get_height();

    float2 inputCenter = (float2(gid) + 0.5) / uniforms.scale - 0.5;
    uint2 inputBase = uint2(floor(inputCenter));

    float4 result;
    if (uniforms.kernelSize <= 3) {
        KernelNxN<3> k;
        k.load(inTexture, inputBase, inWidth, inHeight);
        result = k.applyLanczos(inputBase, inputCenter);
    } else if (uniforms.kernelSize <= 5) {
        KernelNxN<5> k;
        k.load(inTexture, inputBase, inWidth, inHeight);
        result = k.applyLanczos(inputBase, inputCenter);
    } else if (uniforms.kernelSize <= 7) {
        KernelNxN<7> k;
        k.load(inTexture, inputBase, inWidth, inHeight);
        result = k.applyLanczos(inputBase, inputCenter);
    } else {
        KernelNxN<9> k;
        k.load(inTexture, inputBase, inWidth, inHeight);
        result = k.applyLanczos(inputBase, inputCenter);
    }

    outTexture.write(result, gid);
}
