//
//  Blending.metal
//  SnapCore
//
//  Created by Aryan Rogye on 4/23/26.
//

#include <metal_stdlib>
using namespace metal;

kernel void alphaBlendTextures(
                               texture2d<float, access::read> baseTexture    [[texture(0)]],
                               texture2d<float, access::read> overlayTexture [[texture(1)]],
                               texture2d<float, access::write> outTexture    [[texture(2)]],
                               uint2 gid [[thread_position_in_grid]]
                               ) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    float4 base = baseTexture.read(gid);

    if (gid.x >= overlayTexture.get_width() || gid.y >= overlayTexture.get_height()) {
        outTexture.write(base, gid);
        return;
    }

    float4 overlay = overlayTexture.read(gid);
    
    float alpha = overlay.a;
    float outAlpha = alpha + base.a * (1.0 - alpha);
    float3 premultipliedRGB = overlay.rgb * alpha + base.rgb * base.a * (1.0 - alpha);
    float3 rgb = premultipliedRGB / max(outAlpha, 0.0001);
    
    outTexture.write(float4(rgb, outAlpha), gid);
}
