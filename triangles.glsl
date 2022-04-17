// https://www.shadertoy.com/view/XlGBW3
// #pragma use "sdf.glsl"

#define MAX_STEPS 100
#define MAX_DIST 100.0
#define SURF_DIST 0.01
#define PI 3.14159
#define CAM_SPEED 0.7
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

  d = min(d, sdCapsule(p, vec3(a, 0), vec3(b, 0), 0.03));
  d = min(d, sdCapsule(p, vec3(b, 0), vec3(c, 0), 0.03));
  d = min(d, sdCapsule(p, vec3(c, 0), vec3(a, 0), 0.03));

  return d;
}

float sdSphere(in vec3 p, in vec3 o, in float r) {
  return length(p - o) - r;
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
  //d = sdSphere( p, vec3(0, 0, 5.0), 2.0 );
  //return vec4( d, p);
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
    tAngle += sin(iTime * smoothstep(0.3, 0.6, sin((tIndex + i) * 356.4))) * 0.1;
    d = min(d, sdTriangle(opTranslate(p, tPos), tAngle));
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


//https://www.shadertoy.com/view/3s3GDn
float getGlow(float dist, float radius, float intensity){
	return pow(radius / max(dist, 1e-6), intensity);
}

vec4 intersect( in vec3 ro, in vec3 rd, inout float glow )
{
    vec4 res = vec4(-1.0);

    float t = 0.001;
    float tmax = 15.0;
    for( int i=0; i<128; i++ )
    {
        vec4 h = map(ro+t*rd);
        // Calculate the glow at the current distance using the distance based
        // glow function. Accumulate this value over the whole view ray The
        // smaller the step size, the smoother the final result
        //
        // This means everything will glow equally/the same color.
        glow += getGlow(h.x, 1e-3, 0.85);

        if( h.x<1e-6 ) { res=vec4(t,h.yzw); break; }
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

float sceneTime() {
  return mod(iTime, SCENE_LENGTH);
}

// https://docs.chaos.com/display/OSLShaders/Complex+Fresnel+shader
float fresnel(float n, float k, float c) {
    float k2=k*k;
    float rs_num = n*n + k2 - 2*n*c + c*c;
    float rs_den = n*n + k2 + 2*n*c + c*c;
    float rs = rs_num/ rs_den ;

    float rp_num = (n*n + k2)*c*c - 2*n*c + 1;
    float rp_den = (n*n + k2)*c*c + 2*n*c + 1;
    float rp = rp_num/ rp_den ;

    return clamp(0.5*( rs+rp ), 0.0, 1.0);
}

//https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
vec3 ACESFilm(vec3 x){
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

  vec3 ro = vec3(sin(sceneTime() / 3.0) * 0.1, sin(sceneTime() / 4.0) * 0.1, sceneTime() * (1.0 / CAM_SPEED));
  vec3 rd = normalize(vec3(uv.x + sin(sceneTime() / 2.0) * 0.1, uv.y + sin(sceneTime() / 2.3) * 0.09, 1.0));

  // background
  vec3 col = vec3(1.0+rd.y)*0.00;

  float glow = 0.0;
  float d = intersect(ro, rd, glow).x;

  //vec3 glowColour = vec3(0.2, 0.5, 1.0);
  //vec3 glowColour = vec3(0.502, 0.055, 0.075);
  vec3 glowColour = vec3(1.0,0.05,0.3);
  col = glow * glowColour;

  if (d > 0.0) {
    vec3 pos = ro + rd * d;
    vec3 nor = normal(pos);



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

    //vec3 mate = vec3(0.392, 0.051, 0.078);
    ////vec3  f0 = mate;
    //float ks = clamp(0.75,0.0,1.0);
    //float kd = (1.0-ks)*0.125;
    //vec3 f0 = vec3(0.8);

    //// origin light
    //{
    //  vec3 lightPos = vec3(0, 5, -10.0) + ro;
    //  lightPos.xz += vec2(sin(iTime), cos(iTime) * 0.5);
    //  vec3 l = normalize(lightPos - pos);

    //  float dif = 0.5 + 0.5 * dot(nor, l);
    //  dif *= 0.3;
    //  vec3 ref = reflect(rd,nor);
    //  //vec3 spe = vec3(0.9) * smoothstep(0.8, 0.9, dot(ref, l));
    //  //float fre = clamp(1.0 + dot(rd, nor), 0.0, 1.0);
    //  //spe *= f0 + (1.0 - f0)*pow(fre, 5.0);
    //  //spe *= 7.0;
    //  vec3 hal = normalize(l - rd);
    //  float spe = clamp(dot(hal, nor), 0.0, 1.0);
    //  spe = pow(spe, 32.0);

    //  float shadow = clamp(calcSoftshadow(pos+nor*SURF_DIST*0.001, l, 80.0), 0.1, 1.0);
    //  col += dif * mate;
    //  col += spe * dif;
    //  col *= shadow;
    //  //col = vec3(spe);
    //}

    //{
    //  vec3 lig = normalize(vec3(2.0, 0.1, 1.0));
    //  //vec3 lColor = vec3(1.0,0.6, 0.3);
    //  vec3 lColor = vec3(0.3,0.6, 1.0);

    //  float dif = clamp(dot(nor, lig), 0.0, 1.0);

    //  vec3 hal = normalize(lig - rd);
    //  float fre = clamp(1.0 + dot(hal, lig), 0.0, 1.0);
    //  vec3 spe = vec3(1.0) * pow(clamp(dot(hal, nor), 0.0, 1.0), 32.0);
    //  spe *= f0 + (1.0 - f0)*pow(fre, 5.0);
    //  col += dif * lColor * mate;
    //  col += spe * lColor * dif;
    //}
    //// TODO: Metallic lighting

    //vec3 n=vec3(0.27105, 0.67693, 1.3164);
    //vec3 k=vec3(3.6092, 2.6247, 2.2921);
    //vec3 lig = normalize(vec3(0, 5, -10.0) + ro);
    //float thetaCos = abs(dot(-lig,nor));
    //float red=fresnel(n[0], k[0], thetaCos);
    //float green=fresnel(n[1], k[1], thetaCos);
    //float blue=fresnel(n[2], k[2], thetaCos);
    //col = vec3(red, green, blue);

  }
  col = ACESFilm(col);
  col = pow(col, vec3(0.4545)); // gamma correction
  fragColor = vec4(col, 1.0);
}
