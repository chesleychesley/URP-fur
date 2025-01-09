

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


// [Burley 2012, "Physically-Based Shading at Disney"]
float D_GGXaniso1(float ax, float ay, float NoH, float XoH, float YoH)
{
	float a2 = ax * ay;
	float3 V = float3(ay * XoH, ax * YoH, a2 * NoH);
	float S = dot(V, V);

	return(1.0f / PI) * a2 * (a2 / S)* (a2 / S);
}

float Pow5(float n){
	return n*n*n*n*n;
}
// [Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"]
float Vis_SmithJointAniso(float ax, float ay, float NoV, float NoL, float XoV, float XoL, float YoV, float YoL)
{
	float Vis_SmithV = NoL * length(float3(ax * XoV, ay * YoV, NoV));
	float Vis_SmithL = NoV * length(float3(ax * XoL, ay * YoL, NoL));
	return 0.5 * rcp(Vis_SmithV + Vis_SmithL);
}
// [Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"]
float3 F_Schlick_UE4(float VoH,float3 F0,float3 F90)
{
	float Fc = Pow5(1 - VoH);					// 1 sub, 3 mul
	//return Fc + (1 - Fc) * SpecularColor;		// 1 add, 3 mad
	
	// Anything less than 2% is physically impossible and is instead considered to be shadowing
	return F0 +(F90 - F0)*Fc;
}


float3 SlikBRDF(float3 DiffuseColor, float3 SpecularColor, float Roughness, float Metallic, float Anisotropy,
float3 N, float3 T, float3 B, float3 V, float3 L, float3 LightColor, float Shadow)
{
	float Alpha = Roughness * Roughness;
	float a2 = Alpha * Alpha;
	// Anisotropic parameters: ax and ay are the Roughness along the tangent and bitangent
	// Kulla 2017, "Revisiting Physically Based Shading at Imageworks"
	float ax = max(Alpha * (1.0 + Anisotropy), 0.001f);
	float ay = max(Alpha * (1.0 - Anisotropy), 0.001f);
	float3 H = normalize(L + V);
	float NoH = saturate(dot(N, H));
	float NoV = saturate(abs(dot(N, V)) + 1e-5);
	float NoL = saturate(dot(N, L));
	float VoH = saturate(dot(V, H));

	float XoV = dot(T, V);
	float XoL = dot(T, L);
	float XoH = dot(T, H);
	float YoV = dot(B, V);
	float YoL = dot(B, L);
	float YoH = dot(B, H);

	float3 Radiance = NoL * LightColor * Shadow *PI;
	
	

	//直接光镜面反射
	float3 F0 = lerp(0.04, DiffuseColor, Metallic);
	float F90 = 0.5 + 2 * Roughness * pow(VoH, 2);
	float D = D_GGXaniso1(ax, ay, NoH, XoH, YoH);
	float Vis = Vis_SmithJointAniso(ax, ay, NoV, NoL, XoV, XoL, YoV, YoL);
	float3 F = F_Schlick_UE4(VoH, F0, F90);
	float3 SpecularTerm = ((D * Vis) * F) ;
	float3 ks          = F;
	float3 kd          = (1 - ks) * (1 - Metallic);

	//直接光漫反射
	float3 DiffuseTerm = kd *DiffuseColor;

	return ( DiffuseTerm + SpecularTerm)*Radiance;
}

float3 DirectLighting(float3 DiffuseColor, float3 SpecularColor, float Roughness, float Metallic,float3 WorldPos, float Anisotropy, 
	float3 N, float3 T, float3 B, float3 V, float4 shadowCoord, float4 shadowMask)
{
	//主光源
	half3 DirectLighting_MainLight = half3(0, 0, 0);
	{
		Light light = GetMainLight(shadowCoord, WorldPos, shadowMask);
		half3 L = light.direction;
		half3 LightColor = light.color;
		half Shadow = light.shadowAttenuation;
		DirectLighting_MainLight = SlikBRDF(DiffuseColor, SpecularColor, Roughness,Metallic, Anisotropy, N, T, B, V, L, LightColor, Shadow);
	}
	//附加光源
	half3 DirectLighting_AddLight = half3(0, 0, 0);
	#ifdef _ADDITIONAL_LIGHTS
		uint pixelLightCount = GetAdditionalLightsCount();
		for (uint lightIndex = 0; lightIndex < pixelLightCount; ++lightIndex)
		{
			Light light = GetAdditionalLight(lightIndex, WorldPos, shadowMask);
			half3 L = light.direction;
			half3 LightColor = light.color;
			half Shadow = light.shadowAttenuation * light.distanceAttenuation;
			DirectLighting_AddLight += SlikBRDF(DiffuseColor, SpecularColor, Roughness,Metallic, Anisotropy, N, T, B, V, L, LightColor, Shadow);
		}
	#endif

	return DirectLighting_MainLight + DirectLighting_AddLight;
}
float3 AOMultiBounce(float3 BaseColor, float AO)
{
	float3 a = 2.0404 * BaseColor - 0.3324;
	float3 b = -4.7951 * BaseColor + 0.6417;
	float3 c = 2.7552 * BaseColor + 0.6903;
	return max(AO, ((AO * a + b) * AO + c) * AO);
}


half3 EnvBRDFApprox( half3 SpecularColor, half Roughness, half NoV )
{
    // [ Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II" ]
    // Adaptation to fit our G term.
    const half4 c0 = { -1, -0.0275, -0.572, 0.022 };
    const half4 c1 = { 1, 0.0425, 1.04, -0.04 };
    half4 r = Roughness * c0 + c1;
    half a004 = min( r.x * r.x, exp2( -9.28 * NoV ) ) * r.x + r.y;
    half2 AB = half2( -1.04, 1.04 ) * a004 + r.zw;

    // Anything less than 2% is physically impossible and is instead considered to be shadowing
    // Note: this is needed for the 'specular' show flag to work, since it uses a SpecularColor of 0
    AB.y *= saturate( 50.0 * SpecularColor.g );

    return SpecularColor * AB.x + AB.y;
}

half3 PBRaniso(float3 DiffuseColor, float3 SpecularColor, float Roughness, float Metallic, float occlusion, float3 WorldPos,float3 normalTS,float3x3 TBN,float3 reflectDirWS, float3 viewDirWS, float Anisotropy,float normalAniso,float4 shadowmask){
	float4 ShadowCoord = TransformWorldToShadowCoord(WorldPos);
	half3 normalWS = TransformTangentToWorld(normalTS, TBN);

	half3 tangentTS = normalize(normalTS.x*half3(0,0,1)* normalAniso + half3(1,0,0));
	half3 T = TransformTangentToWorld(tangentTS, TBN);
	half3 bitangentTS = normalize(normalTS.y * half3(0, 0, 1) * normalAniso + half3(0, 1, 0));
	half3 B = TransformTangentToWorld(bitangentTS, TBN);
	B = NormalizeNormalPerPixel(B);
	T = NormalizeNormalPerPixel(T);
	

	half3 directLighting = DirectLighting(DiffuseColor,SpecularColor,Roughness,Metallic,WorldPos,Anisotropy,normalWS,T,B,viewDirWS,ShadowCoord,shadowmask);
	
	float3 RadianceSH = SampleSH(normalWS)*DiffuseColor.xyz;

	half3 LD = GlossyEnvironmentReflection(reflectDirWS,WorldPos,Roughness,occlusion);
	float NV = max(0.001,dot(normalWS,viewDirWS));
	half3 env = EnvBRDFApprox(DiffuseColor,Roughness,NV);
	half3 indirect = RadianceSH + LD *env;

	return directLighting +indirect;
}