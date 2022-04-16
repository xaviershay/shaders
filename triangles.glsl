// https://www.shadertoy.com/view/XlGBW3
#pragma use "sdf.glsl"

#define MAX_STEPS 100
#define MAX_DIST 100
#define SURF_DIST 0.01
#define PI 3.14159

float map(in vec3 p) {
  float d = 1000000000;
  //d = min(d, sdSphere(p, vec3(0, 1, 6), 1.0));

  vec2 a = vec2(cos(PI / 2.0), sin(PI / 2.0));
  vec2 b = vec2(cos(PI / 2.0 + 2.0 * PI / 3.0), sin(PI / 2.0 + 2.0 * PI / 3.0));
  vec2 c = vec2(cos(PI / 2.0 + 4.0 * PI / 3.0), sin(PI / 2.0 + 4.0 * PI / 3.0));

  d = min(d, sdCapsule(p, vec3(a, 6), vec3(b, 6), 0.1));
  d = min(d, sdCapsule(p, vec3(b, 6), vec3(c, 6), 0.1));
  d = min(d, sdCapsule(p, vec3(c, 6), vec3(a, 6), 0.1));

  d = min(d, sdCapsule(p, vec3(a, 3), vec3(b, 3), 0.1));
  d = min(d, sdCapsule(p, vec3(b, 3), vec3(c, 3), 0.1));
  d = min(d, sdCapsule(p, vec3(c, 3), vec3(a, 3), 0.1));

  return d;
}

float march(vec3 ro, vec3 rd) {
  float d0 = 0.0;
  float dS = 0.0;

  for (int i = 0; i < MAX_STEPS; i++) {
    vec3 p = ro + rd * d0;
    dS = map(p);
    d0 += dS;
    if (d0 > MAX_DIST || dS < SURF_DIST) break;
  }
  return d0;
}

vec3 normal(in vec3 p) {
  float d = map(p);
  vec2 e = vec2(0.01, 0.0);

  vec3 n = d - vec3(
      map(p - e.xyy),
      map(p - e.yxy),
      map(p - e.yyx));

  return normalize(n);
}

float light(in vec3 p) {
  vec3 lightPos = vec3(0, 5, 6);
  lightPos.xz += vec2(sin(iTime), cos(iTime)) * 2.0;
  vec3 l = normalize(lightPos - p);
  vec3 n = normal(p);

  float dif = clamp(dot(n, l), 0.0, 1.0);
  float d = march(p+n*SURF_DIST*2.0, l);
  if (d < length(lightPos - p)) dif *= 0.1;
  return dif;
}
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

  vec3 ro = vec3(0.0, 0.0, 0.0);
  vec3 rd = normalize(vec3(uv.x, uv.y, 1.0));

  float d = march(ro, rd);

  vec3 p = ro + rd * d;

  float dif = light(p);
  vec3 col = vec3(dif);
  col = pow(col, vec3(0.4545)); // gamma correction
  fragColor = vec4(col, 1.0);
}
