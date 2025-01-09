#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"




//float4 _BaseColor;
float _NormalScale;
int _ShellAmount;
float _ShellStep;
float _AlphaCutout;
float _FurScale;
float _Occlusion;
float4 _baseColor;
float4 _specularColor;
float _rougness;
float _Anisotropy;
float _normalAniso;
float _metallic;

//TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
TEXTURE2D(_FurMap); SAMPLER(sampler_FurMap);
TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
TEXTURE2D(_baseMap); SAMPLER(sampler_baseMap);
TEXTURE2D(_occlusionMap); SAMPLER(sampler_occlusionMap);