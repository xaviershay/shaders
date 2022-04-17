PI = Math::PI

def pow(x, y)
  x ** y
end

def cos(x)
  Math::cos(x)
end

def clamp(x, mn, mx)
  [[mn, x].max, mx].min
end

def ease( edge0, edge1, p)
  p = clamp((p - edge0) / (edge1 - edge0), 0.0, 1.0) - 0.5;

  baseCurve = cos(3 * PI / 2.0 * (pow(2.0 * p, 7) + 1));
  shapeCurve = pow(cos(2 * PI * p) * 0.5 + 0.5, 1);
  smoothCurve = pow(p + 0.5, 2) * (3.0 - 2.0 * (p + 0.5));

  allTogether = baseCurve * shapeCurve + smoothCurve;

  return allTogether;
end

(0..100).each do |i|
  puts ease(0.0, 100.0, i)
end
