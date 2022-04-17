// https://www.shadertoy.com/view/XlGBW3
// #pragma use "sdf.glsl"

#define MAX_STEPS 100
#define MAX_DIST 100.0
#define SURF_DIST 0.01
#define PI 3.14159
#define CAM_SPEED 1.0
#define SCENE_LENGTH 50.0
#define GATE_SPACING 3.0

vec3 opTranslate(in vec3 p, in vec3 a)
{
  return p - a;
}

float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
  vec3 pa = p - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
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

// https://github.com/Michaelangel007/easing
float inOutBack( float edge0, float edge1, float p) {
  p = clamp((p - edge0) / (edge1 - edge0), 0.0, 1.0);

  float m=p-1.0;
  float t=p*2.0;
  float k = 1.70158 * 1.525;

  if (p < 0.5) return p*t*(t*(k+1.0) - k);
  else return 1.0 + 2.0*m*m*(2.0*m*(k+1.0) + k);
}

vec4 map(in vec3 p) {
  float d = MAX_DIST;
  // This needs to match camera speed but then be divided by space between each
  // triangle.
  float tIndex = floor(mod(iTime, SCENE_LENGTH) * (1.0 / CAM_SPEED) / GATE_SPACING) - 6.0;
  vec3 tPos = vec3(0, 0, tIndex * GATE_SPACING);

  for (float i = 0.0; i < 12.0; i++) {
    tPos += vec3(0.0, 0.0, GATE_SPACING);

    float spinDelta = 7.0;
    float spinTime = abs(sin((tIndex + i) * 453.32 + 3563.0)) * spinDelta;
    float tAngle = sin((tIndex + i) * 2354.0 + 23.0) * 0.1;
    tAngle = inOutBack(0.0, 0.7, mod(iTime, spinDelta + 0.7) - spinTime)
      * 2.0 * PI / 3.0 + tAngle;
    d = min(d, sdTriangle(opTranslate(p, tPos), tAngle));
  }

  return vec4(d, p);
}


vec4 intersect( in vec3 ro, in vec3 rd )
{
    vec4 res = vec4(-1.0);

    float t = 0.001;
    float tmax = 15.0;
    for( int i=0; i<128 && t<tmax; i++ )
    {
        vec4 h = map(ro+t*rd);
        if( h.x<0.001 ) { res=vec4(t,h.yzw); break; }
        t += h.x;
    }

    return res;
}

vec3 normal(in vec3 p) {
  float d = map(p).x;
  vec2 e = vec2(0.01, 0.0);

  vec3 n = d - vec3(
      map(p - e.xyy).x,
      map(p - e.yxy).x,
      map(p - e.yyx).x);

  return normalize(n);
}

float calcAO( in vec3 pos, in vec3 nor, in float time )
{
	float occ = 0.0;
  float sca = 1.0;
  for( int i=0; i<5; i++ )
  {
      float h = 0.01 + 0.12*float(i)/4.0;
      float d = map( pos+h*nor ).x;
      occ += (h-d)*sca;
      sca *= 0.95;
  }
  return clamp( 1.0 - 3.0*occ, 0.0, 1.0 );
}

float light(in vec3 p) {
  vec3 lightPos = vec3(0, 5, 0);
  lightPos.xz += vec2(sin(iTime), cos(iTime)) * 2.0;
  vec3 l = normalize(lightPos - p);
  vec3 n = normal(p);

  float occ = calcAO( p, n, iTime );

  float dif = clamp(dot(n, l), 0.0, 1.0);
  float d = intersect(p+n*SURF_DIST*2.0, l).w;
  if (d > 0.0 && d < length(lightPos - p)) dif *= 0.1;
  return dif;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

  vec3 ro = vec3(0.0, 0.0, mod(iTime, SCENE_LENGTH) * (1.0 / CAM_SPEED));
  vec3 rd = normalize(vec3(uv.x, uv.y, 1.0));

  // background
  vec3 col = vec3(1.0+rd.y)*0.00;

  float d = intersect(ro, rd).x;

  if (d > 0.0) {
    vec3 p = ro + rd * d;

    float dif = light(p);
    col += vec3(dif);
  }
  col = pow(col, vec3(0.4545)); // gamma correction
  fragColor = vec4(col, 1.0);
}
