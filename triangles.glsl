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

bool isnan( float val )
{
  return ( val < 0.0 || 0.0 < val || val == 0.0 ) ? false : true;
  // important: some nVidias failed to cope with version below.
  // Probably wrong optimization.
  /*return ( val <= 0.0 || 0.0 <= val ) ? false : true;*/
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

float ease( float edge0, float edge1, float p) {
  p = clamp((p - edge0) / (edge1 - edge0), 0.0, 1.0) - 0.5;

  float baseCurve = cos(3 * PI / 2.0 * ((p < 0.0 ? -pow(-2.0*p, 7) : pow(2.0 * p, 7)) + 1));
  float shapeCurve = pow(cos(2 * PI * p) * 0.5 + 0.5, 1);
  float smoothCurve = pow(p + 0.5, 2) * (3.0 - 2.0 * (p + 0.5));

  float allTogether = baseCurve * shapeCurve + smoothCurve;

  if (isnan(allTogether)) return 0.0;
  return allTogether;
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
    float tEase = inOutBack(0.0, 0.8, mod(iTime, spinDelta + 0.7) - spinTime);
    //float tEase = ease(0.0, 1.7, iTime);
    tAngle = tEase * 2.0 * PI / 3.0 + tAngle;
    d = min(d, sdTriangle(opTranslate(p, tPos), abs(tAngle)));
  }

  return vec4(d, p);
}


float calcSoftshadow( in vec3 ro, in vec3 rd, in float k )
{
    float res = 1.0;

    float tmax = MAX_DIST;
    float t    = 0.001;
    for( int i=0; i<MAX_STEPS; i++ )
    {
        float h = map( ro + rd*t ).x;
        res = min( res, k*h/t );
        t += clamp( h, 0.012, 0.2 );
        if( res<0.001 || t>tmax ) break;
    }

    return clamp( res, 0.0, 1.0 );
}

vec4 intersect( in vec3 ro, in vec3 rd )
{
    vec4 res = vec4(-1.0);

    float t = 0.001;
    float tmax = 15.0;
    for( int i=0; i<128; i++ )
    {
        vec4 h = map(ro+t*rd);
        if( h.x<0.001 ) { res=vec4(t,h.yzw); break; }
        t += h.x;
        if (t >= tmax) break;
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

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

  vec3 ro = vec3(0.0, 0.0, mod(iTime, SCENE_LENGTH) * (1.0 / CAM_SPEED));
  vec3 rd = normalize(vec3(uv.x, uv.y, 1.0));

  // background
  vec3 col = vec3(1.0+rd.y)*0.00;

  float d = intersect(ro, rd).x;

  if (d > 0.0) {
    vec3 pos = ro + rd * d;
    vec3 nor = normal(pos);

    vec3 mate = vec3(0.5, 0.5, 0.5);
    vec3  f0 = mate;

    float ks = clamp(0.75,0.0,1.0);
    float kd = (1.0-ks)*0.125;
//    float dif = light(p);
//    col += vec3(dif);

    // Top light
    // {
    //   vec3  ref = reflect(rd,nor);
    //   float fre = clamp(1.0+dot(nor,rd),0.0,1.0);
    //   float sha = 1.0;
    //   col += kd*mate*25.0*vec3(0.19,0.22,0.24)*(0.6 + 0.4*nor.y)*sha;
    //   col += ks*     25.0*vec3(0.19,0.22,0.24)*sha*smoothstep( -1.0+1.5, 1.0-0.4, ref.y ) * (f0 + (1.0-f0)*pow(fre,5.0));
    // }

    // origin light
    // TODO: Move with camera
    {
// side
      vec3 lightPos = vec3(0, 5, -10.0) + ro;
      lightPos.xz += vec2(sin(iTime), cos(iTime) * 0.5);
      vec3 l = normalize(lightPos - pos);

      float dif = clamp(dot(nor, l), 0.0, 1.0);


      float shadow = clamp(calcSoftshadow(pos+nor*SURF_DIST*2.0, l, 80.0), 0.1, 1.0);
      col += dif * shadow;
    }
    // TODO: Metallic lighting

  }
  col = pow(col, vec3(0.4545)); // gamma correction
  fragColor = vec4(col, 1.0);
}
