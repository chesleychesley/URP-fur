#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


CBUFFER_START(UnityPerMaterial)

float4 _basicColor;
float _occlusion;

float4 _NormalMap_ST;
float _FallingSpeed;
float _noiseStrength;
float _rippleAmount;
float _alpha;
float _noiseStrengthFalls;

float _positionOffset;
float _alphaFallsOffset;

float _bumpScale;
float _roughness;
float _metallic;

float _fresnelOffset;

float _shadowAttenOffsetFall;
float _shadowAttenOffsetFace;
CBUFFER_END

TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
TEXTURE2D(_baseMap); SAMPLER(sampler_baseMap);
TEXTURE2D(_bumpMap); SAMPLER(sampler_bumpMap);
TEXTURE2D(_occlusionMap); SAMPLER(sampler_occlusionMap);
TEXTURE2D(_roughnessMap); SAMPLER(sampler_roughnessMap);
TEXTURE2D(_MetallicMap); SAMPLER(sampler_MetallicMap);