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
    
    int2 softShadowOrigin = cursorOrigin + int2(int(mouse.cursorShadowX), int(mouse.cursorShadowY));
    int2 sharpShadowOrigin = cursorOrigin + int2(int(mouse.cursorShadowSharpX), int(mouse.cursorShadowSharpY));
    
    int2 softLocal  = int2(gid) - softShadowOrigin;
    int2 sharpLocal = int2(gid) - sharpShadowOrigin;
    int2 local      = int2(gid) - cursorOrigin;
    
    float4 finalColor = imageTexture.read(gid);
    const float3 shadowColor = float3(0.0, 0.0, 0.05); // slight blue tint like Apple
    
    // Pass 1: soft outer shadow
    if (softLocal.x >= 0 && softLocal.y >= 0 &&
        softLocal.x < int(cursorWidth) && softLocal.y < int(cursorHeight)) {
        float a = sampleShadowAlpha(cursorTexture, softLocal) * mouse.cursorShadowOpacity;
        finalColor.rgb = shadowColor * a + finalColor.rgb * (1.0 - a);
        finalColor.a   = a + finalColor.a * (1.0 - a);
    }
    
    // Pass 2: tight inner shadow
    if (sharpLocal.x >= 0 && sharpLocal.y >= 0 &&
        sharpLocal.x < int(cursorWidth) && sharpLocal.y < int(cursorHeight)) {
        float a = sampleShadowAlphaSharp(cursorTexture, sharpLocal) * mouse.cursorShadowSharpOpacity;
        finalColor.rgb = shadowColor * a + finalColor.rgb * (1.0 - a);
        finalColor.a   = a + finalColor.a * (1.0 - a);
    }
    
    // Pass 3: cursor on top
    if (local.x >= 0 && local.y >= 0 &&
        local.x < int(cursorWidth) && local.y < int(cursorHeight)) {
        float4 cursorColor = cursorTexture.read(uint2(local));
        finalColor.rgb = cursorColor.rgb * cursorColor.a + finalColor.rgb * (1.0 - cursorColor.a);
        finalColor.a   = cursorColor.a + finalColor.a * (1.0 - cursorColor.a);
    }
    
    outTexture.write(finalColor, gid);
}
