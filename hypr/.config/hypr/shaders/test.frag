#version 300 es
precision mediump float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// ---- tune these ----
const float CURVE  = 0.04;              // barrel distortion strength
const float ABERR  = 0.0008;            // chromatic aberration offset
const vec2  RES    = vec2(1920.0, 1080.0);
// --------------------

void main() {
    vec2 uv = v_texcoord;

    // barrel distortion
    vec2 c = uv - 0.5;
    float r2 = dot(c, c);
    uv = 0.5 + c * (1.0 + CURVE * r2);


    // chromatic aberration
    vec2 ro = vec2(ABERR, 0.0);
    float rr = texture(tex, clamp(uv + ro, 0.0, 1.0)).r;
    float gg = texture(tex, clamp(uv,      0.0, 1.0)).g;
    float bb = texture(tex, clamp(uv - ro, 0.0, 1.0)).b;

    fragColor = vec4(rr, gg, bb, 1.0);
}
