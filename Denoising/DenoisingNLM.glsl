uniform sampler2D input1;
uniform float adsk_result_w, adsk_result_h;
// values below taken from Denoising.cpp
uniform float g_NoiseLevel; // [1, 100]
uniform float g_LerpCoefficient; // [0, 100]
uniform float g_WeightThreshold; // [0, 100]
uniform float g_CounterThreshold; // = 0.0; // 0.75; // [0, 100] / 100 = [0, 1]
uniform float g_GaussianSigma; // = [1, 100]
uniform float g_WindowRadius; // = 3.0; // [1, 10]
uniform float g_BlockRadius; // = 2.0; // [1, 10]
uniform bool g_ShowEdges;

// PSNLM_dynamic_loop (see Denoising.fx)
void main()
{
  // GUI -> local variables
  float gs_NoiseLevel = g_NoiseLevel * 0.01; // [0.01, 1]
  float l_NoiseLevel = 1.0 / (gs_NoiseLevel * gs_NoiseLevel);
  float l_LerpCoefficient = g_LerpCoefficient * 0.01; // [0, 1]
  float l_WeightThreshold = g_WeightThreshold * 0.01; // [0, 1]
  float l_CounterThreshold = g_CounterThreshold * 0.01; // [0, 1]
  float l_GaussianSigma = 1.0 / g_GaussianSigma;
  // uv-coords in [0.0, 1.0]
  vec2 coords = gl_FragCoord.xy;
  vec2 coords01 = gl_FragCoord.xy / vec2( adsk_result_w, adsk_result_h );
  // read pixel color
  vec4 color = texture2D(input1, coords01);
  vec4 result = vec4(0.0, 0.0, 0.0, 1.0);
  vec2 g_Shift = vec2(1.0, 1.0);
  // others ...
  float fCounter = 0.0;
  float fWeight = 0.0;
  float fSum = 0.0;
  float i, j, n, m;
  float invBlockArea = 2.0 * g_BlockRadius + 1.0;
  invBlockArea = 1.0 / (invBlockArea * invBlockArea);
  for (i = -g_WindowRadius; i <= g_WindowRadius; i++) {
    for (j = -g_WindowRadius; j <= g_WindowRadius; j++) {
      fWeight = 0.0;
      vec4 colorC;
      vec2 tex2 = coords + vec2(0.0, 0.0);
      for (n = -g_BlockRadius; n <= g_BlockRadius; n++) {
        for (m = -g_BlockRadius; m <= g_BlockRadius; m++) {
          vec2 coords1 = tex2 + g_Shift * vec2(i + n, j + m);
          vec2 coords2 = tex2 + g_Shift * vec2(    n,     m);
          coords1 = coords1 / vec2( adsk_result_w, adsk_result_h );
          coords2 = coords2 / vec2( adsk_result_w, adsk_result_h );
          vec4 colorB = texture2D(input1, coords1);
          colorC = texture2D(input1, coords2);
          vec3 cWeight = colorB.rgb - colorC.rgb;
          cWeight = cWeight * cWeight;
          fWeight = fWeight + cWeight.r + cWeight.g + cWeight.b;
        }
      }
      vec2 coords3 = coords + g_Shift * vec2(i, j);
      coords3 = coords3 / vec2( adsk_result_w, adsk_result_h );
      colorC = texture2D(input1, coords3);
      fWeight = fWeight * invBlockArea;
      fWeight = exp(-(fWeight * l_NoiseLevel + (i * i + j * j) *
                      l_GaussianSigma));
      fCounter += (fWeight > l_WeightThreshold) ? 1.0: 0.0;
      if (!g_ShowEdges) {
        fSum = fSum + fWeight;
        result.rgb = result.rgb + colorC.rgb * fWeight;
      }
    }
  }
  float iWindowArea = 2.0 * g_WindowRadius + 1.0;
  iWindowArea = iWindowArea * iWindowArea;
  if (!g_ShowEdges) {
    result.rgb = result.rgb / fSum;
    float lerpQ = (fCounter > (l_CounterThreshold * iWindowArea)) ?
      1.0 - l_LerpCoefficient : l_LerpCoefficient;
    result.rgb = mix(result.rgb, color.rgb, lerpQ);
  } else {
    result = vec4(0.0, 0.0, 0.0, 1.0);
    result.rgb = (fCounter > (l_CounterThreshold * iWindowArea)) ?
      vec3(1.0, 0.0, 0.0) : vec3(0.0, 0.0, 1.0);
  }
  // output result
  vec4 final = vec4(result.r, result.g, result.b, 1.0);
  gl_FragColor = final;
}
