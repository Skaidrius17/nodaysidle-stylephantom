#include <metal_stdlib>
using namespace metal;

// MARK: - Timeline Gradient Shader
// Horizontal phase color bands with smoothstep blending

[[ stitchable ]] half4 timelineGradient(
    float2 position,
    half4 color,
    float2 size,
    float phaseCount,
    float time,
    half4 color1,
    half4 color2,
    half4 color3
) {
    float x = position.x / size.x;
    float phases = max(1.0, phaseCount);
    float bandWidth = 1.0 / phases;

    // Determine which phase band we're in
    float phaseIndex = floor(x / bandWidth);
    float localX = fract(x / bandWidth);

    // Blend between phase colors with smoothstep at boundaries
    float blendZone = 0.15;
    float blend = smoothstep(1.0 - blendZone, 1.0, localX);

    // Pick colors based on phase index
    half4 currentColor;
    half4 nextColor;
    int idx = int(phaseIndex) % 3;

    if (idx == 0) { currentColor = color1; nextColor = color2; }
    else if (idx == 1) { currentColor = color2; nextColor = color3; }
    else { currentColor = color3; nextColor = color1; }

    half4 bandColor = mix(currentColor, nextColor, half(blend));

    // Subtle animated shimmer
    float shimmer = sin(x * 12.0 + time * 2.0) * 0.03 + 0.97;
    bandColor.rgb *= half(shimmer);

    // Vertical fade (brighter at center)
    float y = position.y / size.y;
    float vFade = 1.0 - abs(y - 0.5) * 0.6;
    bandColor.rgb *= half(vFade);

    return bandColor;
}

// MARK: - Vector Heatmap Shader
// Radial heatmap with cool-to-warm color mapping

[[ stitchable ]] half4 vectorHeatmap(
    float2 position,
    half4 color,
    float2 size,
    float intensity,
    float time
) {
    float2 center = size * 0.5;
    float2 uv = (position - center) / min(size.x, size.y);
    float dist = length(uv);

    // Radial falloff
    float heat = clamp(intensity * (1.0 - dist * 1.5), 0.0, 1.0);

    // Cool-to-warm color mapping (blue -> green -> yellow -> red)
    half3 coolColor = half3(0.2, 0.4, 0.9);   // Blue
    half3 midColor  = half3(0.3, 0.9, 0.4);   // Green
    half3 warmColor = half3(0.95, 0.3, 0.15);  // Red
    half3 hotColor  = half3(1.0, 0.9, 0.2);    // Yellow

    half3 mapped;
    if (heat < 0.33) {
        mapped = mix(coolColor, midColor, half(heat / 0.33));
    } else if (heat < 0.66) {
        mapped = mix(midColor, hotColor, half((heat - 0.33) / 0.33));
    } else {
        mapped = mix(hotColor, warmColor, half((heat - 0.66) / 0.34));
    }

    // Subtle pulse
    float pulse = 0.95 + 0.05 * sin(time * 3.0 + dist * 8.0);
    mapped *= half(pulse);

    return half4(mapped, half(heat * 0.85 + 0.15));
}

// MARK: - Evolution Transition Shader
// Wipe effect controlled by float t

[[ stitchable ]] half4 evolutionTransition(
    float2 position,
    half4 color,
    float2 size,
    float progress,
    half4 fromColor,
    half4 toColor
) {
    float x = position.x / size.x;

    // Soft wipe with feathered edge
    float edge = progress;
    float feather = 0.08;
    float blend = smoothstep(edge - feather, edge + feather, x);

    // Diamond pattern at the transition edge
    float y = position.y / size.y;
    float diamond = abs(fract(y * 8.0) - 0.5) * 0.04;
    blend = smoothstep(edge - feather + diamond, edge + feather + diamond, x);

    return mix(fromColor, toColor, half(blend));
}
