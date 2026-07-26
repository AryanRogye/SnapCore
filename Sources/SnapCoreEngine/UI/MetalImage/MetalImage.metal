// Shared Metal image shaders for iOS and macOS.
#include <metal_stdlib>
using namespace metal;

struct MetalImageVertexIn {
    float2 position;
};

struct MetalImageVertexOut {
    float4 position [[position]];
    float2 texturePosition;
    float viewAspect;
};

struct MetalImageViewport {
    float2 origin;
    float scale;
    float viewAspect;
};

vertex MetalImageVertexOut snapCoreMetalImageVertexShader(
    const device MetalImageVertexIn *vertices [[buffer(0)]],
    constant MetalImageViewport &viewport [[buffer(1)]],
    uint vertexID [[vertex_id]]
) {
    MetalImageVertexOut output;

    float2 vertexPosition = vertices[vertexID].position;
    vertexPosition = (vertexPosition - viewport.origin) * viewport.scale;

    float2 samplePosition =
        (vertexPosition / viewport.scale) + viewport.origin;
    float2 textureCoordinates = (samplePosition + 1) / 2;
    textureCoordinates.y = 1 - textureCoordinates.y;

    output.texturePosition = textureCoordinates;
    output.viewAspect = viewport.viewAspect;
    output.position = float4(vertexPosition, 0, 1);
    return output;
}

fragment float4 snapCoreMetalImageFragmentShader(
    MetalImageVertexOut input [[stage_in]],
    texture2d<float> texture [[texture(0)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear
    );

    float textureAspect =
        float(texture.get_width()) / float(texture.get_height());
    float viewAspect = max(input.viewAspect, 0.0001);
    float2 coordinates = input.texturePosition;
    float ratio = viewAspect / textureAspect;

    if (ratio < 1) {
        float offset = (1 - ratio) * 0.5;
        coordinates.x = coordinates.x * ratio + offset;
    } else {
        float inverseRatio = 1 / ratio;
        float offset = (1 - inverseRatio) * 0.5;
        coordinates.y = coordinates.y * inverseRatio + offset;
    }

    float4 color = texture.sample(textureSampler, coordinates);
    return float4(color.rgb, 1);
}
