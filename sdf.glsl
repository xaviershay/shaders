float sdSphere(in vec3 p, in vec3 o, in float r) {
  return length(p - o) - r;
}
