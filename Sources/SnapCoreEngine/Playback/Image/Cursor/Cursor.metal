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
};

kernel void stitchCursor(
                         texture2d<float, access::read>  imageTexture   [[texture(0)]],
                         texture2d<float, access::read>  cursorTexture  [[texture(1)]],
                         texture2d<float, access::write> outTexture     [[texture(2)]],
                         constant MousePosition& mouse                  [[buffer(0)]],
                         uint2 gid                                      [[thread_position_in_grid]]
                         ) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    float4 baseColor = imageTexture.read(gid);
    
    uint cursorWidth = cursorTexture.get_width();
    uint cursorHeight = cursorTexture.get_height();
    
    int2 cursorOrigin = int2(
                             int(mouse.x - mouse.hotspotX),
                             int(outTexture.get_height() - mouse.y - mouse.hotspotY)
                             );
    int2 local = int2(gid) - cursorOrigin;
    
    float4 finalColor = baseColor;
    
    if (local.x >= 0 && local.y >= 0 &&
        local.x < cursorWidth && local.y < cursorHeight) {
        
        float4 cursorColor = cursorTexture.read(uint2(local));
        
        // standard alpha blend
        finalColor.rgb = cursorColor.rgb * cursorColor.a + baseColor.rgb * (1.0 - cursorColor.a);
        finalColor.a = cursorColor.a + baseColor.a * (1.0 - cursorColor.a);
    }
    
    outTexture.write(finalColor, gid);
}
