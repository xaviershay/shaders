// https://iquilezles.org/articles/distfunctions/

float sdSphere(in vec3 p, in vec3 o, in float r) {
  return length(p - o) - r;
}

float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
  vec3 pa = p - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}
