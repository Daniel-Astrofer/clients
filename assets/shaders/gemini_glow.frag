#include <flutter/runtime_effect.glsl>

// Gemini edge aurora — header band to mid-balance; pull floods the upper screen.

uniform vec2 uSize;
uniform float uTime;
uniform float uPull;
uniform float uIntensity;
uniform float uTheater;
uniform float uSurge;
uniform vec4 uPrimary;
uniform vec4 uSecondary;

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
    vec2 uv = FlutterFragCoord().xy / safeSize;
    float t = uTime;
    float pull = clamp(uPull, 0.0, 1.0);
    float theater = clamp(uTheater, 0.0, 1.0);
    float surge = clamp(uSurge, 0.0, 1.0);

    float energy = clamp(
        uIntensity * (1.0 + 0.66 * pull + 0.42 * theater + 0.70 * surge),
        0.0,
        1.55
    );

    // Rest: soft floor near mid-balance. Pull: modest fill (not to rect bottom).
    float floorStart = mix(0.70, 0.82, pull);
    float floorEnd = mix(1.0, 1.02, pull);
    float inBand = 1.0 - smoothstep(floorStart, floorEnd, uv.y);
    // Keep crown alive into the overscroll strip (uv near 0).
    inBand *= smoothstep(-0.08, 0.02, uv.y);
    if (inBand <= 0.001 || energy <= 0.01) {
        fragColor = vec4(0.0);
        return;
    }

    float edge = abs(uv.x - 0.5) * 2.0;
    float tall = 0.30 + 0.70 * (edge * edge);

    // Faster traveling fronts while pulling.
    float speed = 1.0 + 1.4 * pull;
    float leftTravel = fract(t * 0.08 * speed + 0.12);
    float rightTravel = fract(t * 0.07 * speed + 0.61);
    float leftFront = exp(-pow((uv.x - leftTravel * 0.85) * 3.2, 2.0));
    float rightFront = exp(-pow(((1.0 - uv.x) - rightTravel * 0.85) * 3.2, 2.0));
    float travel = 0.35 + 0.65 * max(leftFront, rightFront);
    travel = mix(travel, 0.45 + 0.55 * max(leftFront, rightFront), theater * 0.5);
    // Pull: keep more field even between crests so the upper screen fills.
    travel = mix(travel, max(travel, 0.72), pull);

    float n = fbm(vec2(uv.x * 2.4 + t * 0.18 * speed, uv.y * 3.5 - t * 0.12 * speed));
    float n2 = fbm(vec2(uv.x * 3.8 - t * 0.14 * speed, uv.y * 2.2 + t * 0.09 * speed + 4.0));

    float amp = (0.050 + 0.055 * pull + 0.025 * theater) * tall * travel;
    float y0 = mix(0.34, 0.42, pull) + 0.04 * theater;

    float thickBoost = 0.090 + 0.06 * pull;
    float r1 = ribbon(uv, y0 + n * 0.04, amp * 1.15, 1.05, t * 0.55 * speed, thickBoost);
    float r2 = ribbon(uv, y0 + 0.06 + n2 * 0.035, amp * 0.95, 0.82, -t * 0.42 * speed + 1.7, thickBoost * 0.9);
    float r3 = ribbon(uv, y0 - 0.05 + n * 0.03, amp * 0.80, 1.45, t * 0.72 * speed + 2.4, thickBoost * 0.7);
    float r4 = ribbon(uv, y0 + 0.10, amp * 1.25, 0.70, t * 0.33 * speed + 4.1, thickBoost * 1.1);

    vec2 leftC = vec2(0.08 + 0.04 * sin(t * 0.4), y0 + 0.02 * cos(t * 0.35));
    vec2 rightC = vec2(0.92 + 0.04 * cos(t * 0.38), y0 + 0.02 * sin(t * 0.31));
    float leftRad = mix(0.42, 0.58, pull);
    float rightRad = mix(0.22, 0.36, pull);
    float leftGlow = exp(-dot((uv - leftC) / vec2(leftRad, rightRad), (uv - leftC) / vec2(leftRad, rightRad)));
    float rightGlow = exp(-dot((uv - rightC) / vec2(leftRad, rightRad), (uv - rightC) / vec2(leftRad, rightRad)));

    vec2 crown = vec2(0.50 + 0.06 * sin(t * 0.25), mix(0.12, 0.22, pull) + 0.03 * theater);
    float crownGlow = exp(-dot(
        (uv - crown) / vec2(mix(0.55, 0.75, pull), mix(0.20, 0.38, pull)),
        (uv - crown) / vec2(mix(0.55, 0.75, pull), mix(0.20, 0.38, pull))
    ));

    // Pull wash — softer / shorter reach (−30%) so it doesn't hit the floor.
    float pullWash = pull * 0.70 * exp(-pow((uv.y - 0.22) / 0.42, 2.0)) * (0.55 + 0.45 * n);

    float field = r1 * 0.90 + r2 * 0.75 + r3 * 0.55 + r4 * 0.65;
    field += leftGlow * 0.55 * tall + rightGlow * 0.55 * tall;
    field += crownGlow * (0.70 + 0.45 * theater + 0.55 * surge + 0.55 * pull);
    field += pullWash;
    field *= inBand * mix(travel, 1.0, pull * 0.65);

    float topBias = 1.0 + (0.75 + 0.45 * pull) * pow(1.0 - smoothstep(0.0, 0.55, uv.y), 1.25);
    field *= topBias;

    vec3 blue = vec3(0.25, 0.47, 0.95);
    vec3 purple = vec3(0.58, 0.38, 0.96);
    vec3 pink = vec3(0.91, 0.45, 0.72);
    vec3 mint = vec3(0.37, 0.92, 0.83);
    vec3 primary = uPrimary.rgb;
    vec3 secondary = uSecondary.rgb;

    float mixT = clamp(uv.x + 0.25 * sin(t * 0.5 + uv.y * 4.0) + (n - 0.5) * 0.35, 0.0, 1.0);
    vec3 gemini = mix(blue, mix(purple, pink, mixT), clamp(edge * 0.85 + n2 * 0.25, 0.0, 1.0));
    gemini = mix(gemini, mint, r3 * 0.35);
    float accentMix = 0.38 + 0.22 * theater + 0.12 * pull;
    gemini = mix(gemini, mix(primary, secondary, 0.5 + 0.5 * sin(t * 0.3)), accentMix);

    float glow = pow(clamp(field, 0.0, 1.8), mix(1.08, 0.92, pull)) * energy * (0.95 + 0.20 * pull);
    glow = glow / (1.0 + glow * mix(0.55, 0.40, pull));

    vec3 color = gemini * glow;
    fragColor = vec4(color, glow);
}
