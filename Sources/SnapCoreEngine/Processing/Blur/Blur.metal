//
//  Blur.metal
//  SnapCore
//
//  Created by Aryan Rogye on 4/11/26.
//

#include <metal_stdlib>
#include "../KernelNxN.metalh"
using namespace metal;

/**
 * Blur Has 2 Things
 * Radius
 * detail (Sigma)
 */

struct BlurUniforms {
    int radius;
    float detail;
};

//kernel void apply_blur(
//                       texture2d<float, access::read>  inTexture  [[texture(0)]],
//                       texture2d<float, access::write> outTexture [[texture(1)]],
//                       constant BlurUniforms& uniforms            [[buffer(0)]],
//                       uint2 gid [[thread_position_in_grid]]
//                       ) {
//    uint width  = inTexture.get_width();
//    uint height = inTexture.get_height();
//    if (gid.x >= width || gid.y >= height) return;
//    
//    int radius = uniforms.radius;
//    float sigma = uniforms.detail;
//    float totalWeight = 0.0;
//    float4 result = float4(0.0);
//    
//    for (int dy = -radius; dy <= radius; dy++) {
//        for (int dx = -radius; dx <= radius; dx++) {
//            int x = clamp(int(gid.x) + dx, 0, int(width)  - 1);
//            int y = clamp(int(gid.y) + dy, 0, int(height) - 1);
//            float w = exp(-float(dx*dx + dy*dy) / (2.0 * sigma * sigma));
//            result += inTexture.read(uint2(x, y)) * w;
//            totalWeight += w;
//        }
//    }
//    
//    outTexture.write(clamp(result / totalWeight, 0.0, 1.0), gid);
//}

kernel void apply_blur(
                       texture2d<float, access::read>  inTexture  [[texture(0)]],
                       texture2d<float, access::write> outTexture [[texture(1)]],
                       constant BlurUniforms& uniforms [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]
                       ) {
    
    /// Determine width and height of texture to make sure its valid
    uint width  = inTexture.get_width();
    uint height = inTexture.get_height();
    
    if (gid.x >= width || gid.y >= height) return;
    
    int radius = uniforms.radius;
    int diameter = (radius * 2) + 1;
    float sigma = uniforms.detail;
    
    float4 blur;
    
    if (diameter == 3) {
        KernelNxN<3> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
    }
    else if (diameter == 5) {
        KernelNxN<5> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
    }
    else if (diameter == 7) {
        KernelNxN<7> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
    }
    else if (diameter == 9) {
        KernelNxN<9> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
    }
    else if (diameter == 11) {
        KernelNxN<11> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
    }
    else if (diameter == 13) {
        KernelNxN<13> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
    }
    else if (diameter == 15) {
        KernelNxN<15> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
    }
    else if (diameter == 17) {
        KernelNxN<17> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
    }
    else {
        KernelNxN<3> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
    }
    
    outTexture.write(blur, gid);
}

kernel void bloom_blur(
                       texture2d<float, access::read>  inTexture  [[texture(0)]],
                       texture2d<float, access::write> outTexture [[texture(1)]],
                       constant BlurUniforms& uniforms [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]
                       ) {
    uint width  = inTexture.get_width();
    uint height = inTexture.get_height();
    
    if (gid.x >= width || gid.y >= height) return;
    
    int radius = min(max(uniforms.radius, 1), 32);
    float sigma = max(uniforms.detail, 0.0001);
    float totalWeight = 0.0;
    float alphaWeight = 0.0;
    float3 premultipliedRGB = float3(0.0);
    
    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            int sampleX = clamp(int(gid.x) + x, 0, int(width) - 1);
            int sampleY = clamp(int(gid.y) + y, 0, int(height) - 1);
            float weight = exp(-float(x * x + y * y) / (2.0 * sigma * sigma));
            float4 sample = inTexture.read(uint2(sampleX, sampleY));
            
            premultipliedRGB += sample.rgb * sample.a * weight;
            alphaWeight += sample.a * weight;
            totalWeight += weight;
        }
    }
    
    float outAlpha = alphaWeight / max(totalWeight, 0.0001);
    float3 outRGB = premultipliedRGB / max(alphaWeight, 0.0001);
    
    outTexture.write(float4(clamp(outRGB, 0.0, 1.0), clamp(outAlpha, 0.0, 1.0)), gid);
}
