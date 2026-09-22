#version 440
// nightcity — desktop overlay: perspective grid, horizon glow, data rain
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 res;
    vec4 accent;
    vec4 accent2;
};

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void main() {
    vec2 uv = qt_TexCoord0;          // 0..1, y grows downward
    float hz = 0.68;                 // horizon line
    vec3 col = vec3(0.0);
    float a = 0.0;

    // ---------- grid below the horizon ----------
    if (uv.y > hz) {
        float d = (uv.y - hz) / (1.0 - hz);           // 0 at horizon, 1 at bottom
        float persp = 1.0 / max(d, 0.002);
        float x = (uv.x - 0.5) * (res.x / res.y);
        float vx = x * persp * 0.9;                    // lines converging to the centre
        float vz = persp * 0.22 - time * 0.30;         // lines flowing toward the viewer
        float gx = abs(fract(vx + 0.5) - 0.5);
        float gz = abs(fract(vz + 0.5) - 0.5);
        float lx = 1.0 - smoothstep(0.0, fwidth(vx) * 1.4, gx);
        float lz = 1.0 - smoothstep(0.0, fwidth(vz) * 1.4, gz);
        float grid = max(lx, lz) * smoothstep(0.0, 0.25, d);
        col += accent.rgb * grid;
        a += grid * 0.38;
    }

    // ---------- horizon glow ----------
    float glow = exp(-abs(uv.y - hz) * 38.0);
    col += mix(accent.rgb, accent2.rgb, 0.35) * glow;
    a += glow * 0.30;

    // ---------- sparse data rain above the horizon ----------
    if (uv.y < hz) {
        float cols = 110.0;
        float ci = floor(uv.x * cols);
        float h = hash(ci);
        if (h > 0.78) {                                // only some columns carry rain
            float cx = abs(fract(uv.x * cols) - 0.5);
            float lane = 1.0 - smoothstep(0.05, 0.18, cx);
            float head = fract(time * (0.04 + 0.08 * hash(ci + 3.0)) + h * 9.0);
            float y = uv.y / hz;
            float dist = head - y;
            float tail = (dist > 0.0 && dist < 0.18) ? (1.0 - dist / 0.18) : 0.0;
            tail = tail * tail;
            col += accent2.rgb * tail * lane;
            a += tail * lane * 0.45;
        }
    }

    a = clamp(a, 0.0, 0.85);
    fragColor = vec4(col * a, a) * qt_Opacity;      // premultiplied alpha
}
