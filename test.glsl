void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord.xy / iResolution.xy;
  fragColor = vec4(uv.x, uv.y, 0, 1);
}
