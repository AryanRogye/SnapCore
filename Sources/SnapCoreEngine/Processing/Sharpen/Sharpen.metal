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
    int radius;
    float detail;
};


kernel void sharpen_kernel(
                           texture2d<float, access::read>  inTexture  [[texture(0)]],
                           texture2d<float, access::write> outTexture [[texture(1)]],
                           constant SharpenUniforms& uniforms [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]
                           ) {
    /// Determine width and height of texture to make sure its valid
    uint width  = inTexture.get_width();
    uint height = inTexture.get_height();
    
    if (gid.x >= width || gid.y >= height) return;
    
    /// Get Sharpness
    float sharpness = uniforms.sharpness;
    
    int radius = uniforms.radius;
    int diameter = (radius * 2) + 1;
    float sigma = uniforms.detail;
    
    /// Possible are: 3, 5, 7, 9, 11, 13, 15, 17
    /// Radius is 1 - 8
    
    float4 original;
    float4 blur;
    
    if (diameter == 3) {
        KernelNxN<3> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
        original = k.v[diameter/2][diameter/2];
    }
    else if (diameter == 5) {
        KernelNxN<5> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
        original = k.v[diameter/2][diameter/2];
    }
    else if (diameter == 7) {
        KernelNxN<7> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
        original = k.v[diameter/2][diameter/2];
    }
    else if (diameter == 9) {
        KernelNxN<9> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
        original = k.v[diameter/2][diameter/2];
    }
    else if (diameter == 11) {
        KernelNxN<11> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
        original = k.v[diameter/2][diameter/2];
    }
    else if (diameter == 13) {
        KernelNxN<13> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
        original = k.v[diameter/2][diameter/2];
    }
    else if (diameter == 15) {
        KernelNxN<15> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
        original = k.v[diameter/2][diameter/2];
    }
    else if (diameter == 17) {
        KernelNxN<17> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
        original = k.v[diameter/2][diameter/2];
    }
    else {
        KernelNxN<3> k;
        k.load(inTexture, gid, width, height);
        blur = k.applyGaussian(sigma);
        original = k.v[diameter/2][diameter/2];
    }
    
    float4 detail = original - blur;
    float4 sharpened = original + detail * sharpness;

    /// write back out to the outTexture
    outTexture.write(clamp(sharpened, 0.0, 1.0), gid);
}


//kernel void sharpen_kernel_old_new(
//                           texture2d<float, access::read>  inTexture  [[texture(0)]],
//                           texture2d<float, access::write> outTexture [[texture(1)]],
//                           constant SharpenUniforms& uniforms [[buffer(0)]],
//                           uint2 gid [[thread_position_in_grid]]
//                           ) {
//    /// Determine width and height of texture to make sure its valid
//    uint width  = inTexture.get_width();
//    uint height = inTexture.get_height();
//    
//    if (gid.x >= width || gid.y >= height) return;
//    
//    /// Get Sharpness
//    float sharpness = uniforms.sharpness;
//
//    /// Load in a Kernel
//    KernelNxN<3> k;
//    k.load(inTexture, gid, width, height);
//    
//    /// Blur The Pixel
//    float4 blur = k.applyGaussian(0.5);
//    
//    /// Grab Original Pixel
//    float4 original = k.v[1][1];
//    
//    /// Sharpness = original - blur * sharpness
//    float4 detail = original + blur * sharpness;
//    
//    /// write back out to the outTexture
//    outTexture.write(clamp(detail, 0.0, 1.0), gid);
//}

//kernel void sharpen_kernel_old(
//                           texture2d<float, access::read>  inTexture  [[texture(0)]],
//                           texture2d<float, access::write> outTexture [[texture(1)]],
//                           constant SharpenUniforms& uniforms [[buffer(0)]],
//                           uint2 gid [[thread_position_in_grid]]
//                           ) {
//
//    float sharpness = uniforms.sharpness;
//
//    uint width  = inTexture.get_width();
//    uint height = inTexture.get_height();
//
//    if (gid.x >= width || gid.y >= height) return;
//
//    KernelNxN<3> k;
//    k.load(inTexture, gid, width, height);
//
//    float weights[3][3] = {
//        { -0.0023, -0.0432,            -0.0023 },
//        { -0.0432, sharpness - 0.8180, -0.0432 },
//        { -0.0023, -0.0432,            -0.0023 }
//    };
//    float4 result = k.convolve(weights);
//    result.a = k.v[1][1].a;
//
//    outTexture.write(clamp(result, 0.0, 1.0), gid);
//}
