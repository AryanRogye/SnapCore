//
//  sharpen.metal
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

#include <metal_stdlib>
using namespace metal;

struct SharpenUniforms {
    float sharpness;
};

struct Kernel3x3 {
    float4 v[3][3];
    
    void load(texture2d<float, access::read> tex, uint2 gid, uint width, uint height) {
        uint x0 = gid.x == 0        ? 0        : gid.x - 1;
        uint x1 = gid.x == width-1  ? width-1  : gid.x + 1;
        uint y0 = gid.y == 0        ? 0        : gid.y - 1;
        uint y1 = gid.y == height-1 ? height-1 : gid.y + 1;
        
        float4 center = tex.read(gid);
        float4 top    = tex.read(uint2(gid.x, y0));
        float4 bottom = tex.read(uint2(gid.x, y1));
        float4 left   = tex.read(uint2(x0, gid.y));
        float4 right  = tex.read(uint2(x1, gid.y));
        float4 topLeft = tex.read(uint2(x0, y0));
        float4 topRight = tex.read(uint2(x1, y0));
        float4 bottomLeft = tex.read(uint2(x0, y1));
        float4 bottomRight = tex.read(uint2(x1, y1));
        
        v[0][0] = topLeft;
        v[0][1] = top;
        v[0][2] = topRight;
        
        v[1][0] = left;
        v[1][1] = center;
        v[1][2] = right;
        
        v[2][0] = bottomLeft;
        v[2][1] = bottom;
        v[2][2] = bottomRight;
    }
    
    float4 convolve(float weights[3][3]) {
        float4 result = float4(0);
        for (int r = 0; r < 3; r++)
            for (int c = 0; c < 3; c++)
                result += weights[r][c] * v[r][c];
        return result;
    }
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
    
    Kernel3x3 k;
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
