//
//  Illuminance.metal
//  SnapCore
//
//  Created by Aryan Rogye on 4/20/26.
//

#include <metal_stdlib>
#include "../KernelNxN.metalh"
using namespace metal;

struct IlluminanceDetectionUniforms {
    float brightnessThreshold;
};

float rgb2luminance(float3 c) {
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

kernel void detect_illuminance(
                           texture2d<float, access::read>  inTexture  [[texture(0)]],
                           texture2d<float, access::write> outTexture [[texture(1)]],
                           constant IlluminanceDetectionUniforms& uniforms [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]
                           ) {
    /// 0.0 Everything Passes 1.0 Almost Nothing Passes only extreme highlights
    float threshold = uniforms.brightnessThreshold;

    float3 rgbColor = inTexture.read(gid).rgb;
    float luminance = rgb2luminance(rgbColor);

    float isBrightValue = step(threshold, luminance);
    bool isBright = isBrightValue > 0.0;

    if (isBright) {
        /// write black for debugging
        outTexture.write(float4(0.0, 0.0, 0.0, 0.0), gid);
    } else {
        /// write original
        outTexture.write(float4(rgbColor, 1.0), gid);
    }
}
