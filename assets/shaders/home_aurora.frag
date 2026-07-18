#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec2 uPointer;
uniform vec4 uPrimary;
uniform vec4 uSecondary;
uniform float uIntensity;
uniform float uMotion;
uniform float uTopInset;
uniform float uInteraction;

out vec4 fragColor;

float ellipseGlow(vec2 uv, vec2 center, vec2 radius) {
    vec2 delta = (uv - center) / radius;
    float distanceSquared = dot(delta, delta);
    float core = 1.0 - smoothstep(0.0, 1.0, distanceSquared);
    return core * core;
}

void main() {
    vec2 safeSize = max(uSize, vec2(1.0));
    vec2 uv = FlutterFragCoord().xy / safeSize;
    float time = uTime * max(uMotion, 0.15);
    float inset = clamp(uTopInset, 0.0, 0.16);
    float interaction = clamp(uInteraction, 0.0, 1.0);

    // Independent breathe phases — lobes differ in intensity and tempo.
    float breathA = 0.78 + 0.22 * sin(time * 0.92);
    float breathB = 0.72 + 0.28 * sin(time * 1.18 + 1.65);
    float breathC = 0.80 + 0.20 * sin(time * 0.68 + 3.05);
    float globalBreath = 0.86 + 0.14 * sin(time * 0.48);
    float interactionBoost = 1.0 + 0.55 * interaction;

    vec2 restingFocus = vec2(0.50, 0.14 + inset * 0.35);
    vec2 focus = mix(restingFocus, clamp(uPointer, vec2(0.0), vec2(1.0)), interaction);

    // Drift + slight vertical lift so the stage "inhales" upward.
    vec2 centerA = vec2(
        0.24 + sin(time * 0.51) * 0.075,
        0.13 + inset + cos(time * 0.33) * 0.032 + breathA * 0.012
    );
    vec2 centerB = vec2(
        0.78 + cos(time * 0.43) * 0.080,
        0.12 + inset + sin(time * 0.29) * 0.038 + breathB * 0.010
    );
    vec2 centerC = vec2(
        0.50 + sin(time * 0.27) * 0.10,
        0.28 + inset * 0.45 + cos(time * 0.23) * 0.045 + breathC * 0.014
    );

    float sizePulseA = 0.94 + 0.10 * breathA;
    float sizePulseB = 0.92 + 0.12 * breathB;
    float sizePulseC = 0.96 + 0.08 * breathC;

    float glowA = ellipseGlow(uv, centerA, vec2(0.70, 0.32) * sizePulseA);
    float glowB = ellipseGlow(uv, centerB, vec2(0.66, 0.30) * sizePulseB);
    float glowC = ellipseGlow(uv, centerC, vec2(0.80, 0.42) * sizePulseC);
    float focusGlow = ellipseGlow(uv, focus, vec2(0.40, 0.26));

    vec3 primary = uPrimary.rgb;
    vec3 secondary = uSecondary.rgb;
    vec3 bridge = mix(primary, secondary, 0.5 + 0.12 * sin(time * 0.35));

    float strength = clamp(uIntensity * globalBreath * interactionBoost, 0.0, 1.15);
    vec3 light = primary * glowA * (0.70 * breathA);
    light += secondary * glowB * (0.62 * breathB);
    light += bridge * glowC * (0.40 * breathC);
    light += mix(secondary, primary, 0.35) * focusGlow * (0.14 + 0.34 * interaction);

    // Soft vertical falloff — stage light dies before the feed zone.
    float falloff = 1.0 - smoothstep(0.42, 0.98, uv.y);
    falloff *= falloff;

    vec3 color = light * strength * falloff;
    color = color / (vec3(1.0) + color);
    fragColor = vec4(color, 1.0);
}
