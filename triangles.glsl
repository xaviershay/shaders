// https://www.shadertoy.com/view/XlGBW3
#pragma use "sdf.glsl"

#define MAX_STEPS 100
#define MAX_DIST 100.0
#define SURF_DIST 0.01
#define PI 3.14159
#define CAM_SPEED 1.0
#define SCENE_LENGTH 5.0

vec3 opTranslate(in vec3 p, in vec3 a)
{
  return p - a;
}
// Create multiple copies of an object - https://iquilezles.org/articles/distfunctions
vec3 opRepLimZ( in vec3 p, in float s, in vec3 lima, in vec3 limb )
{
    p.z = p.z-s*clamp(round(p.z/s),lima.z, limb.z);
    return p;
}

float sdTriangle(in vec3 p, in float t)
{
  float d = MAX_DIST;

  vec2 a = vec2(cos(PI / 2.0 + t), sin(PI / 2.0 + t));
  vec2 b = vec2(cos(PI / 2.0 + t + 2.0 * PI / 3.0), sin(PI / 2.0 + t + 2.0 * PI / 3.0));
  vec2 c = vec2(cos(PI / 2.0 + t + 4.0 * PI / 3.0), sin(PI / 2.0 + t + 4.0 * PI / 3.0));

  d = min(d, sdCapsule(p, vec3(a, 0), vec3(b, 0), 0.05));
  d = min(d, sdCapsule(p, vec3(b, 0), vec3(c, 0), 0.05));
  d = min(d, sdCapsule(p, vec3(c, 0), vec3(a, 0), 0.05));

  return d;
}

float easeInOutElastic( float edge0, float edge1, float x ) {
  const float c5 = (2 * PI) / 4.5;

  x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);

  return x <= 0.0
    ? 0.0
    : x >= 1.0
    ? 1.0
    : x < 0.5
    ? -(pow(2, 20.0 * x - 10.0) * sin((20.0 * x - 11.125) * c5)) / 2.0
    : (pow(2, -20.0 * x + 10.0) * sin((20.0 * x - 11.125) * c5)) / 2.0 + 1.0;
}

// https://github.com/Michaelangel007/easing
float inOutBack( float edge0, float edge1, float p) {
  p = clamp((p - edge0) / (edge1 - edge0), 0.0, 1.0);

  float m=p-1;
  float t=p*2;
  float k = 1.70158 * 1.525;

  if (p < 0.5) return p*t*(t*(k+1) - k);
  else return 1 + 2*m*m*(2*m*(k+1) + k);
}

float mySmoothstep(float edge0, float edge1, float x) {

    // Scale the value of x respect to edge0 edge1, and clamp in the interval [0.0, 1.0]
  	x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);

    // Evaluate a polinomial
  	return x * x * (3. - 2. * x);
}

float map(in vec3 p) {
  float d = MAX_DIST;
  // This needs to match camera speed but then be divided by space between each
  // triangle.
  vec3 cam = vec3(0, 0, floor(mod(iTime, SCENE_LENGTH) * (1.0 / CAM_SPEED) / 3.0));

  vec3 q = p;
  vec3 r = opRepLimZ(q,3.0,vec3(-10,10,0) + cam,vec3(10, 10, 6) + cam);
  //d = min(d, sdTriangle(r, 2 * PI + sin(p.z)*0.08));
  d = min(d, sdTriangle(r,
    floor((p.z - 1.0) / 3.0) == 2.0 ?
      inOutBack(0.0, 0.7, mod(iTime, SCENE_LENGTH)) * 2.0 * PI / 3.0 :
      (2 * PI + sin(p.z)*0.08)));

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

  vec3 ro = vec3(0.0, 0.0, mod(iTime, SCENE_LENGTH) * (1.0 / CAM_SPEED));
  vec3 rd = normalize(vec3(uv.x, uv.y, 1.0));

  float d = march(ro, rd);

  vec3 p = ro + rd * d;

  float dif = light(p);
  vec3 col = vec3(dif);
  col = pow(col, vec3(0.4545)); // gamma correction
  fragColor = vec4(col, 1.0);
}
