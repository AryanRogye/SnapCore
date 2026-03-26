//
//  Cursor.metal
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

#include <metal_stdlib>
using namespace metal;

struct MousePosition {
    float x;
    float y;
    float hotspotX;
    float hotspotY;
    
    float cursorShadowX;
    float cursorShadowY;
    float cursorShadowOpacity;
    
    float cursorShadowSharpX;
    float cursorShadowSharpY;
    float cursorShadowSharpOpacity;
    
    float currentAngle;
    float dx;
    float dy;
};

// Soft outer shadow — large gaussian (sigma=6, radius=12)
float sampleShadowAlpha(texture2d<float, access::read> cursorTexture, int2 p) {
    uint w = cursorTexture.get_width();
    uint h = cursorTexture.get_height();
    
    const int RADIUS = 12;
    const float SIGMA = 6.0;
    
    float shadow = 0.0;
    float totalWeight = 0.0;
    
    for (int dy = -RADIUS; dy <= RADIUS; dy++) {
        for (int dx = -RADIUS; dx <= RADIUS; dx++) {
            int2 s = p + int2(dx, dy);
            if (s.x < 0 || s.y < 0 || s.x >= int(w) || s.y >= int(h)) continue;
            float g = exp(-float(dx*dx + dy*dy) / (2.0 * SIGMA * SIGMA));
            shadow += cursorTexture.read(uint2(s)).a * g;
            totalWeight += g;
        }
    }
    
    float raw = totalWeight > 0.0 ? shadow / totalWeight : 0.0;
    return pow(raw, 0.65);
}

// Tight inner shadow — small gaussian (sigma=2, radius=4)
float sampleShadowAlphaSharp(texture2d<float, access::read> cursorTexture, int2 p) {
    uint w = cursorTexture.get_width();
    uint h = cursorTexture.get_height();
    
    const int RADIUS = 4;
    const float SIGMA = 2.0;
    
    float shadow = 0.0;
    float totalWeight = 0.0;
    
    for (int dy = -RADIUS; dy <= RADIUS; dy++) {
        for (int dx = -RADIUS; dx <= RADIUS; dx++) {
            int2 s = p + int2(dx, dy);
            if (s.x < 0 || s.y < 0 || s.x >= int(w) || s.y >= int(h)) continue;
            float g = exp(-float(dx*dx + dy*dy) / (2.0 * SIGMA * SIGMA));
            shadow += cursorTexture.read(uint2(s)).a * g;
            totalWeight += g;
        }
    }
    
    float raw = totalWeight > 0.0 ? shadow / totalWeight : 0.0;
    return pow(raw, 0.8); // less lift than soft — stays darker near edge
}

kernel void stitchCursor(
                         texture2d<float, access::read>  imageTexture   [[texture(0)]],
                         texture2d<float, access::read>  cursorTexture  [[texture(1)]],
                         texture2d<float, access::write> outTexture     [[texture(2)]],
                         constant MousePosition& mouse                  [[buffer(0)]],
                         uint2 gid                                      [[thread_position_in_grid]]
                         ) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;
    
    uint cursorWidth  = cursorTexture.get_width();
    uint cursorHeight = cursorTexture.get_height();
    
    int2 cursorOrigin = int2(
                             int(mouse.x - mouse.hotspotX),
                             int(outTexture.get_height() - mouse.y - mouse.hotspotY)
                             );
    
    int2 softShadowOrigin  = cursorOrigin + int2(int(mouse.cursorShadowX),      int(mouse.cursorShadowY));
    int2 sharpShadowOrigin = cursorOrigin + int2(int(mouse.cursorShadowSharpX), int(mouse.cursorShadowSharpY));
    
    float4 finalColor = imageTexture.read(gid);
    const float3 shadowColor = float3(0.0, 0.0, 0.05);
    
    // shared rotation
    float angleRad = mouse.currentAngle * (M_PI_F / 180.0);
    float cosA = cos(angleRad);
    float sinA = sin(angleRad);
    float2 center = float2(float(cursorWidth) * 0.5, float(cursorHeight) * 0.5);
    
    // rotated soft shadow local
    float2 softOffset   = float2(gid) - float2(softShadowOrigin);
    float2 softCentered = softOffset - center;
    int2 rotatedSoftLocal = int2(float2(
                                        cosA * softCentered.x + sinA * softCentered.y,
                                        -sinA * softCentered.x + cosA * softCentered.y
                                        ) + center);
    
    // rotated sharp shadow local
    float2 sharpOffset   = float2(gid) - float2(sharpShadowOrigin);
    float2 sharpCentered = sharpOffset - center;
    int2 rotatedSharpLocal = int2(float2(
                                         cosA * sharpCentered.x + sinA * sharpCentered.y,
                                         -sinA * sharpCentered.x + cosA * sharpCentered.y
                                         ) + center);
    
    // rotated cursor local
    float2 cursorOffset   = float2(gid) - float2(cursorOrigin);
    float2 cursorCentered = cursorOffset - center;
    int2 rotatedLocal = int2(float2(
                                    cosA * cursorCentered.x + sinA * cursorCentered.y,
                                    -sinA * cursorCentered.x + cosA * cursorCentered.y
                                    ) + center);
    
    // Pass 1: soft outer shadow
    if (rotatedSoftLocal.x >= 0 && rotatedSoftLocal.y >= 0 &&
        rotatedSoftLocal.x < int(cursorWidth) && rotatedSoftLocal.y < int(cursorHeight)) {
        float a = sampleShadowAlpha(cursorTexture, rotatedSoftLocal) * mouse.cursorShadowOpacity;
        finalColor.rgb = shadowColor * a + finalColor.rgb * (1.0 - a);
        finalColor.a   = a + finalColor.a * (1.0 - a);
    }
    
    // Pass 2: tight inner shadow
    if (rotatedSharpLocal.x >= 0 && rotatedSharpLocal.y >= 0 &&
        rotatedSharpLocal.x < int(cursorWidth) && rotatedSharpLocal.y < int(cursorHeight)) {
        float a = sampleShadowAlphaSharp(cursorTexture, rotatedSharpLocal) * mouse.cursorShadowSharpOpacity;
        finalColor.rgb = shadowColor * a + finalColor.rgb * (1.0 - a);
        finalColor.a   = a + finalColor.a * (1.0 - a);
    }
    
    // Pass 3: cursor on top
    if (rotatedLocal.x >= 0 && rotatedLocal.y >= 0 &&
        rotatedLocal.x < int(cursorWidth) && rotatedLocal.y < int(cursorHeight)) {
        float4 cursorColor = cursorTexture.read(uint2(rotatedLocal));
        finalColor.rgb = cursorColor.rgb * cursorColor.a + finalColor.rgb * (1.0 - cursorColor.a);
        finalColor.a   = cursorColor.a + finalColor.a * (1.0 - cursorColor.a);
    }
    
    outTexture.write(finalColor, gid);
}
