#include <flutter/runtime_effect.glsl>

// Gemini edge aurora — one continuous canvas from pull extension through band.
// No per-frame remapping. bandY = (fragCoord.y - uVerticalOriginPx) / uLogicalHeightPx
// is continuous across extension (negative) and band (0..1).
// Extension ribbons, extended topBias, and pull-reactive crown keep the
// pull-to-refresh area alive with the same rich animation as the band.

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

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
    for (int i = 0; i < 4; i++) {
        v += a * valueNoise(p);
        p = m * p;
        a *= 0.5;
    }
    return v;
}

float ribbon(vec2 uv, float baseY, float amp, float freq, float phase, float thick) {
    float y = baseY
        + amp * sin(uv.x * freq * 6.2831853 + phase)
        + amp * 0.45 * sin(uv.x * freq * 11.0 + phase * 1.7)
        + amp * 0.22 * sin(uv.x * freq * 3.1 - phase * 0.6);
    float d = abs(uv.y - y);
    return smoothstep(thick, 0.0, d);
}

void main() {
    vec2 safeSize = max(uSize, vec2(1.0));
    vec2 fragCoord = FlutterFragCoord().xy;

    // Continuous coordinate — no special-case remapping.
    // Extension: bandY < 0    Band: bandY ∈ [0, 1]
    float bandY = (fragCoord.y - uVerticalOriginPx) / uLogicalHeightPx;
    vec2 uv = vec2(fragCoord.x / safeSize.x, bandY);

    float t = uTime;
    float pull = clamp(uPull, 0.0, 1.0);
    float theater = clamp(uTheater, 0.0, 1.0);
    float surge = clamp(uSurge, 0.0, 1.0);

    float energy = clamp(
        uIntensity * (
            1.0
            + 0.66 * pull * mix(1.0, 0.28, theater)
            + 0.16 * theater
            + 0.32 * surge
        ),
        0.0,
        1.15
    );

    // ── Visibility band ──────────────────────────────────────────────────
    float floorStart = 0.70;
    float floorEnd = 1.0;
    // Fade out at the bottom only — top extends freely into pull area.
    float inBand = 1.0 - smoothstep(floorStart, floorEnd, uv.y);

    // Atmospheric extinction for deep extension (soft dimming, never black).
    float extDist = max(-uv.y, 0.0);
    float extFade = 1.0 / (1.0 + extDist * 0.07 + extDist * extDist * 0.007);
    // Pull brightens the extension — the deeper you pull, the more alive.
    extFade = mix(extFade, 1.0, pull * 0.55);
    inBand *= uv.y < 0.0 ? extFade : 1.0;

    if (inBand <= 0.001 || energy <= 0.01) {
        fragColor = vec4(0.0);
        return;
    }

    // ── Animation parameters ─────────────────────────────────────────────
    float edge = abs(uv.x - 0.5) * 2.0;
    float tall = 0.30 + 0.70 * (edge * edge);

    float speed = mix(1.0, 0.62, theater);
    float leftTravel = fract(t * 0.035 * speed + 0.12);
    float rightTravel = fract(t * 0.028 * speed + 0.61);
    float leftFront = exp(-pow((uv.x - leftTravel * 0.85) * 1.55, 2.0));
    float rightFront = exp(-pow(((1.0 - uv.x) - rightTravel * 0.85) * 1.55, 2.0));
    float travel = 0.42 + 0.58 * max(leftFront, rightFront);
    travel = mix(travel, 0.55 + 0.45 * max(leftFront, rightFront), theater * 0.35);
    travel = mix(travel, max(travel, 0.55), pull * 0.45);

    float n  = fbm(vec2(uv.x * 2.4 + t * 0.09 * speed, uv.y * 3.5 - t * 0.06 * speed));
    float n2 = fbm(vec2(uv.x * 3.8 - t * 0.07 * speed, uv.y * 2.2 + t * 0.045 * speed + 4.0));

    float amp = (0.050 + 0.012 * theater) * tall * travel;
    float y0 = 0.34 + 0.02 * theater;

    // ── Main ribbon band ─────────────────────────────────────────────────
    float thickBoost = 0.090;
    float r1 = ribbon(uv, y0 + n * 0.04, amp * 1.15, 0.85, t * 0.28 * speed, thickBoost);
    float r2 = ribbon(uv, y0 + 0.06 + n2 * 0.035, amp * 0.95, 0.68, -t * 0.22 * speed + 1.7, thickBoost * 0.9);
    float r3 = ribbon(uv, y0 - 0.05 + n * 0.03, amp * 0.80, 1.05, t * 0.34 * speed + 2.4, thickBoost * 0.7);
    float r4 = ribbon(uv, y0 + 0.10, amp * 1.25, 0.58, t * 0.18 * speed + 4.1, thickBoost * 1.1);

    // ── Extension ribbon layers — same animation shifted upward ──────────
    // Three extra ribbon sets spaced ~0.55 apart so the pattern never goes dead.
    float extW = smoothstep(0.0, -1.6, uv.y);
    float er1a = ribbon(uv, y0 - 0.52 + n * 0.05, amp * 1.10, 0.88, t * 0.28 * speed + 2.3, thickBoost * 0.78);
    float er2a = ribbon(uv, y0 - 0.46 + n2 * 0.04, amp * 0.90, 0.72, -t * 0.22 * speed + 3.9, thickBoost * 0.68);
    float er3a = ribbon(uv, y0 - 0.58 + n * 0.035, amp * 0.75, 1.08, t * 0.34 * speed + 4.6, thickBoost * 0.58);
    float er4a = ribbon(uv, y0 - 0.40 + n2 * 0.03, amp * 0.68, 0.74, -t * 0.18 * speed + 5.2, thickBoost * 0.82);

    float er1b = ribbon(uv, y0 - 1.04 + n * 0.055, amp * 1.05, 0.91, t * 0.28 * speed + 4.0, thickBoost * 0.68);
    float er2b = ribbon(uv, y0 - 0.98 + n2 * 0.045, amp * 0.85, 0.75, -t * 0.22 * speed + 5.6, thickBoost * 0.58);
    float er3b = ribbon(uv, y0 - 1.10 + n * 0.038, amp * 0.70, 1.10, t * 0.34 * speed + 6.3, thickBoost * 0.50);

    float er1c = ribbon(uv, y0 - 1.56 + n * 0.06, amp * 1.00, 0.94, t * 0.28 * speed + 5.7, thickBoost * 0.58);
    float er2c = ribbon(uv, y0 - 1.50 + n2 * 0.048, amp * 0.80, 0.78, -t * 0.22 * speed + 7.3, thickBoost * 0.50);

    // Blend extension ribbons in proportion to pull depth.
    float r1f = mix(r1, max(r1, max(er1a, max(er1b, er1c))), extW);
    float r2f = mix(r2, max(r2, max(er2a, max(er2b, er2c))), extW);
    float r3f = mix(r3, max(r3, max(er3a, max(er3b, r3))), extW);
    float r4f = mix(r4, max(r4, max(er4a, r4)), extW * 0.85);

    // ── Glow spots ───────────────────────────────────────────────────────
    vec2 leftC  = vec2(0.08 + 0.03 * sin(t * 0.22), y0 + 0.015 * cos(t * 0.20));
    vec2 rightC = vec2(0.92 + 0.03 * cos(t * 0.20), y0 + 0.015 * sin(t * 0.18));
    float leftRad = 0.42;
    float rightRad = 0.22;
    float leftGlow  = exp(-dot((uv - leftC)  / vec2(leftRad, rightRad), (uv - leftC)  / vec2(leftRad, rightRad)));
    float rightGlow = exp(-dot((uv - rightC) / vec2(leftRad, rightRad), (uv - rightC) / vec2(leftRad, rightRad)));

    // ── Crown (center-top glow) — extends upward during pull ─────────────
    vec2 crown = vec2(0.50 + 0.04 * sin(t * 0.14), 0.12 + 0.015 * theater);
    float crownGlow = exp(-dot(
        (uv - crown) / vec2(0.55, 0.20),
        (uv - crown) / vec2(0.55, 0.20)
    ));

    // Pull-reactive extension crown — moves upward as you pull.
    float pullDepth = clamp(-uv.y, 0.0, 1.0);
    float extCrownStrength = pullDepth * (0.55 + 0.35 * pull);
    vec2 extCrown = vec2(0.50 + 0.04 * sin(t * 0.18), 0.12 - pullDepth * 0.65);
    float extCrownGlow = exp(-dot(
        (uv - extCrown) / vec2(0.60, 0.28),
        (uv - extCrown) / vec2(0.60, 0.28)
    )) * extCrownStrength;

    // ── Compose field ────────────────────────────────────────────────────
    float field = r1f * 0.90 + r2f * 0.75 + r3f * 0.55 + r4f * 0.65;
    field += leftGlow * 0.55 * tall + rightGlow * 0.55 * tall;
    field += crownGlow * (0.70 + 0.22 * theater + 0.28 * surge + 0.40 * pull);
    field += extCrownGlow;
    field *= inBand * mix(travel, 0.85 + 0.15 * travel, pull * 0.5);

    // topBias extends smoothly into the extension.
    float topBias = 1.0 + 1.5 * pow(clamp(1.0 - uv.y * 0.55, 0.0, 1.0), 1.25);
    field *= topBias;

    // ── Color ────────────────────────────────────────────────────────────
    vec3 blue    = vec3(0.25, 0.47, 0.95);
    vec3 purple  = vec3(0.58, 0.38, 0.96);
    vec3 pink    = vec3(0.91, 0.45, 0.72);
    vec3 mint    = vec3(0.37, 0.92, 0.83);
    vec3 primary = uPrimary.rgb;
    vec3 secondary = uSecondary.rgb;

    float mixT = clamp(uv.x + 0.18 * sin(t * 0.28 + uv.y * 3.0) + (n - 0.5) * 0.28, 0.0, 1.0);
    vec3 gemini = mix(blue, mix(purple, pink, mixT), clamp(edge * 0.85 + n2 * 0.25, 0.0, 1.0));
    gemini = mix(gemini, mint, r3f * 0.35);

    float accentMix = 0.38 + 0.10 * pull;
    float warm   = smoothstep(0.35, 0.75, primary.r - primary.b);
    float green  = smoothstep(0.18, 0.52, primary.g - max(primary.r, primary.b) * 0.85);
    accentMix = mix(accentMix, min(accentMix + 0.32, 0.72), warm);
    accentMix = mix(accentMix, min(accentMix + 0.22, 0.62), green);
    accentMix = mix(accentMix, min(accentMix + 0.14, 0.68), theater);
    float breathe = 0.5 + 0.22 * sin(t * 0.11);
    gemini = mix(gemini, mix(primary, secondary, breathe), accentMix);

    float glow = pow(clamp(field, 0.0, 1.8), mix(1.08, 0.96, pull))
               * energy * (0.95 + 0.18 * pull);
    glow = glow / (1.0 + glow * mix(0.55, 0.45, pull));

    vec3 color = gemini * glow;
    fragColor = vec4(color, glow);
}
