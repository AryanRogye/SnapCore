//
//  Illuminance.metal
//  SnapCore
//
//  Created by Aryan Rogye on 4/20/26.
//

#include <metal_stdlib>
#include "../KernelNxN.metalh"
using namespace metal;

// MARK: - Uniform
struct IlluminanceRecoveryUniforms {
    float brightnessThreshold;
    float recovery;
    uint showDebug;
};

struct IlluminanceDetectionUniforms {
    float brightnessThreshold;
    float contrastControl;
};

struct IlluminanceDetectionAlternameUniforms {
    float brightnessThreshold;
    int radius;
};



// MARK: - RGB Luminance Helper
float rgb2luminance(float3 c) {
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

kernel void illuminance_recovery(
                                texture2d<float, access::read>  inTexture  [[texture(0)]],
                                texture2d<float, access::write> outTexture [[texture(1)]],
                                constant IlluminanceRecoveryUniforms& uniforms [[buffer(0)]],
                                uint2 gid [[thread_position_in_grid]]
                                ) {
    /// Determine width and height of texture to make sure its valid
    uint width  = inTexture.get_width();
    uint height = inTexture.get_height();
    
    if (gid.x >= width || gid.y >= height) return;
    
    float3 rgbColor = inTexture.read(gid).rgb;
    float L_in = rgb2luminance(rgbColor);
    
    float threshold = uniforms.brightnessThreshold;
    
    float isBrightValue = step(threshold, L_in);
    bool isBright = isBrightValue > 0.0;
    
    if (isBright) {
        float recovery = uniforms.recovery;
        float excess = smoothstep(threshold, 1.0, L_in);
        float showDebug = uniforms.showDebug;
        
        if (showDebug) {
            outTexture.write(float4(0.0, 1.0, 0.0, 1.0), gid);
        } else {
            // blend between original and darkened based on excess
            float3 darkened = rgbColor * recovery;
            float3 finalColor = mix(rgbColor, darkened, excess);
            
            outTexture.write(float4(finalColor, 1.0), gid);
        }
    } else {
        /// write original
        outTexture.write(float4(rgbColor, 1.0), gid);
    }
}

// MARK: - Approach 2
/**
 * The regular approach would be really good when its post processing,
 * but realtime, its very laggy, so this altername version aims to get the
 * nearest neighbors and calculate the contrastControl on the GPU
 */
kernel void detect_illuminance_alternate(
                               texture2d<float, access::read>  inTexture  [[texture(0)]],
                               texture2d<float, access::write> outTexture [[texture(1)]],
                               constant IlluminanceDetectionAlternameUniforms& uniforms [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]
                                         ) {
    
    /// Determine width and height of texture to make sure its valid
    uint width  = inTexture.get_width();
    uint height = inTexture.get_height();
    
    if (gid.x >= width || gid.y >= height) return;
    
    /// 0.0 Everything Passes 1.0 Almost Nothing Passes only extreme highlights
    float threshold = uniforms.brightnessThreshold;
    int radius = uniforms.radius;
    int diameter = (radius * 2) + 1;
    
    float contrastControl;
    
    if (diameter == 3) {
        KernelNxN<3> k;
        k.load(inTexture, gid, width, height);
        contrastControl = k.contrastControl();
    }
    else if (diameter == 5) {
        KernelNxN<5> k;
        k.load(inTexture, gid, width, height);
        contrastControl = k.contrastControl();
    }
    else if (diameter == 7) {
        KernelNxN<7> k;
        k.load(inTexture, gid, width, height);
        contrastControl = k.contrastControl();
    }
    else if (diameter == 9) {
        KernelNxN<9> k;
        k.load(inTexture, gid, width, height);
        contrastControl = k.contrastControl();
    }
    else if (diameter == 11) {
        KernelNxN<11> k;
        k.load(inTexture, gid, width, height);
        contrastControl = k.contrastControl();
    }
    else if (diameter == 13) {
        KernelNxN<13> k;
        k.load(inTexture, gid, width, height);
        contrastControl = k.contrastControl();
    }
    else if (diameter == 15) {
        KernelNxN<15> k;
        k.load(inTexture, gid, width, height);
        contrastControl = k.contrastControl();
    }
    else if (diameter == 17) {
        KernelNxN<17> k;
        k.load(inTexture, gid, width, height);
        contrastControl = k.contrastControl();
    }
    else {
        KernelNxN<3> k;
        k.load(inTexture, gid, width, height);
        contrastControl = k.contrastControl();
    }

    float3 rgbColor = inTexture.read(gid).rgb;
    float L_in = rgb2luminance(rgbColor);
    
    /// Reinhard with m as the exponent
    float L_out = pow(L_in, contrastControl) / (1.0 + pow(L_in, contrastControl));
    
    float isBrightValue = step(threshold, L_out);
    bool isBright = isBrightValue > 0.0;
    
    if (isBright) {
        /// write green for debugging
        outTexture.write(float4(0.0, 1.0, 0.0, 1.0), gid);
    } else {
        /// write original
        outTexture.write(float4(rgbColor, 1.0), gid);
    }
}


// MARK: - Approach 1
kernel void detect_illuminance(
                           texture2d<float, access::read>  inTexture  [[texture(0)]],
                           texture2d<float, access::write> outTexture [[texture(1)]],
                           constant IlluminanceDetectionUniforms& uniforms [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]
                           ) {

    /// Determine width and height of texture to make sure its valid
    uint width  = inTexture.get_width();
    uint height = inTexture.get_height();

    if (gid.x >= width || gid.y >= height) return;

    /// 0.0 Everything Passes 1.0 Almost Nothing Passes only extreme highlights
    float threshold = uniforms.brightnessThreshold;
    /**
     * dark night scene -> close to 1
     * bright day scene -> close to 0.3
     */
    float contrastControl = uniforms.contrastControl;

    float3 rgbColor = inTexture.read(gid).rgb;
    float L_in = rgb2luminance(rgbColor);

    /// Reinhard with m as the exponent
    float L_out = pow(L_in, contrastControl) / (1.0 + pow(L_in, contrastControl));
    float3 tonemapped = rgbColor * (L_out / max(L_in, 0.0001));

    float isBrightValue = step(threshold, L_out);
    bool isBright = isBrightValue > 0.0;

    // float isBrightValue = step(threshold, luminance);
    // bool isBright = isBrightValue > 0.0;

    if (isBright) {
        float blend = smoothstep(threshold, 1.0, L_out);
        float3 finalColor = mix(rgbColor, tonemapped, blend);
        outTexture.write(float4(finalColor, 1.0), gid);
        //   outTexture.write(float4(0.0, 0.0, 0.0, 0.0), gid);
    } else {
      /// write original
      outTexture.write(float4(rgbColor, 1.0), gid);
    }
}
