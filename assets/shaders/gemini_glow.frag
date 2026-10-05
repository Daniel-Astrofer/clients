#include <flutter/runtime_effect.glsl>

// A diffuse edge halo on one continuous canvas, including the pull extension.
// Keep this uniform order in sync with _GeminiGlowShaderPainter.
uniform vec2 uSize;
uniform float uTime;
uniform float uPull;
uniform float uIntensity;
uniform float uTheater;
uniform float uSurge;
uniform vec4 uPrimary;
uniform vec4 uSecondary;
uniform float uVerticalOriginPx;
uniform float uLogicalHeightPx;

out vec4 fragColor;

float halo(vec2 uv, vec2 center, vec2 radius) {
    vec2 distance = (uv - center) / radius;
    return exp(-dot(distance, distance));
}

void main() {
    vec2 safeSize = max(uSize, vec2(1.0));
    vec2 fragCoord = FlutterFragCoord().xy;
    // Extension: bandY < 0. The origin never moves during pull-to-refresh.
    float bandY = (fragCoord.y - uVerticalOriginPx)
        / max(uLogicalHeightPx, 1.0);
    vec2 uv = vec2(fragCoord.x / safeSize.x, bandY);

    float theater = clamp(uTheater, 0.0, 1.0);
    float pull = clamp(uPull, 0.0, 1.0);
    float surge = clamp(uSurge, 0.0, 1.0);
    float energy = clamp(uIntensity, 0.0, 0.38)
        * (1.0 + 0.06 * theater + 0.06 * pull + 0.08 * surge);
    float bottomFade = 1.0 - smoothstep(0.40, 1.0, uv.y);

    if (bottomFade <= 0.001 || energy <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    // Slow, small orbits keep the light ambient without a moving horizon.
    float t = uTime * mix(0.055, 0.040, theater);
    vec2 leftCenter = vec2(
        0.02 + 0.025 * sin(t),
        0.02 + 0.018 * cos(t * 0.83)
    );
    vec2 rightCenter = vec2(
        1.04 + 0.018 * cos(t * 0.71),
        -0.10 + 0.022 * sin(t * 0.67)
    );
    float leftHalo = halo(uv, leftCenter, vec2(0.56, 0.56));
    float rightHalo = halo(uv, rightCenter, vec2(0.50, 0.62));

    // Keep the center fixed and dark so the balance remains the focal point.
    float centerShade = 1.0
        - 0.78 * halo(uv, vec2(0.50, 0.43), vec2(0.42, 0.46));
    float field = (leftHalo * 0.62 + rightHalo * 0.34)
        * centerShade * bottomFade;
    float breath = 0.97 + 0.03 * sin(t * 0.61);
    float alpha = clamp(field * energy * breath, 0.0, 0.22);

    // The ledger/scene accent owns the color. Its companion is only a nearby
    // tint; no independent rainbow channels or time-driven hue changes.
    float companionMix = 0.10 + 0.08 * smoothstep(0.15, 0.95, uv.x);
    vec3 accent = mix(uPrimary.rgb, uSecondary.rgb, companionMix);
    fragColor = vec4(accent * alpha, alpha);
}
