#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Utils.hlsl"

struct Attributes{
	float4 positionOS : POSITION;
	float3 normalOS : NORMAL;
	float4 tangentOS : TANGENT;
	float2 uv: TEXCOORD0;

	float2 lightmapUV : TEXCOORD1;
	float2 dynamicLightmapUV : TEXCOORD2;


};

struct Varyings{
	float4 positionCS: SV_POSITION;
	float3 positionWS: TEXCOORD0;
	float3 normalWS: TEXCOORD1;
	float3 tangentWS: TEXCOORD2;
	float3 bitangentWS : TEXCOORD3;
	float4 uv: TEXCOORD4;
	float4 shadowCoord : TEXCOORD5;

	DECLARE_LIGHTMAP_OR_SH(lightmapUV,vertexSH,6);
	float4 fogFactorAndVertexLight : TEXCOORD7;
	
	#ifdef DYNAMICLIGHTMAP_ON
		float2 dynamicLightmapUV : TEXCOORD8;
	#endif




};


Varyings vert(Attributes input){

	Varyings output = (Varyings)0;
	VertexPositionInputs positionInput = GetVertexPositionInputs(input.positionOS.xyz);
	VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS,input.tangentOS);

	output.positionCS = positionInput.positionCS;
	output.positionWS = positionInput.positionWS;
	output.normalWS = normalInput.normalWS;
	output.tangentWS = normalInput.tangentWS;
	output.bitangentWS = normalize(cross(output.normalWS,output.tangentWS)*input.tangentOS.w);
	output.uv.xy= input.uv.xy;
	output.uv.zw = TRANSFORM_TEX(input.uv.xy,_NormalMap);

#ifdef _USETYPE_OPAQUE
	float3 vertexLight = VertexLighting(positionInput.positionWS,normalInput.normalWS);
	half fogFac = ComputeFogFactor(output.positionCS.z);
	output.fogFactorAndVertexLight = float4(fogFac,vertexLight.xyz);

	OUTPUT_LIGHTMAP_UV(input.lightmapUV,unity_LightmapST,output.lightmapUV);
	OUTPUT_SH(output.normalWS.xyz,output.vertexSH);

	output.shadowCoord = GetShadowCoord(positionInput);
	#ifdef DYNAMICLIGHTMAP_ON
		output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
	#endif
#endif
	return output;
}


half4 frag( Varyings input): SV_Target{
//公用数据
	float3x3 TBN = float3x3(input.tangentWS,input.bitangentWS,input.normalWS);
	

	float4 shadowCoord = float4(0,0,0,0);
	#if defined( REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
		shadowCoord = input.shadowCoord;
	#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
		shadowCoord = TransformWorldToShadowCoord(input.positionWS);
	#endif


	Light MainLight = GetMainLight(shadowCoord);
	float3 LightColor = MainLight.color;
	
	half shadowAttenuation = MainLight.shadowAttenuation;
	
	half distanceAttenuation = unity_LightData.z;
	float3 lightDirWS = normalize(MainLight.direction);
	float3 viewDirWS = normalize(_WorldSpaceCameraPos - input.positionWS);
	
	//水面
	#ifdef _USETYPE_WATERFACE
		float4 decodeMap = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,input.uv);//获取水波纹理
		float3 normalWS = normalize(TransformTangentToWorld(Ripple(decodeMap,input.positionWS),TBN));//由贴图获得法线 ripple函数在utils的hlsl里

		
	//diffuse 
		float4 diffuse = _basicColor;

		
	//reflection 
		float NoV =max(0.01,dot(normalWS,viewDirWS));
		half fresnel = saturate(pow5(1-NoV)); //pow5在utils的hlsl里

		float3 reflectDirWS = reflect(-viewDirWS,normalWS);
		half4 enCol = SAMPLE_TEXTURECUBE(unity_SpecCube0,samplerunity_SpecCube0,reflectDirWS);
		half3 envHDRCol = DecodeHDREnvironment(enCol,unity_SpecCube0_HDR);
		

		half3 finalCol = lerp(diffuse.xyz,envHDRCol, clamp(fresnel+_fresnelOffset,0,1))*lerp(shadowAttenuation,1,_shadowAttenOffsetFace)*distanceAttenuation;
		half alpha = lerp(_alpha,1,fresnel);
		return half4(finalCol,alpha);

		//水流
	#elif defined(_USETYPE_WATERFALLS)
		float NoV =max(0.01,dot(input.normalWS,viewDirWS));
		float2 uv = float2(input.uv.z,input.uv.w + _Time.y*_FallingSpeed+rand(input.positionWS)*0.01*_noiseStrengthFalls);//增加噪波
		float4 color= SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,uv)*_basicColor;

		//reflection
		float3 reflectDirWS = reflect(-viewDirWS,input.normalWS);
		half3 envHDRCol = Getreflection(reflectDirWS);
		half fresnel = saturate(pow5(1-NoV));


		float3 foam = lerp(_basicColor.xyz,envHDRCol,clamp(input.uv.y+_positionOffset,0,1))*lerp(shadowAttenuation,1,_shadowAttenOffsetFall)*distanceAttenuation;
		float alpha = clamp(color.a +_alphaFallsOffset ,0,1);
		foam = lerp(foam,envHDRCol,fresnel);

		return half4(foam,alpha);

	#else
	//opaque
		float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_bumpMap,sampler_bumpMap,input.uv),_bumpScale);
		float3 normalWS = normalize(TransformTangentToWorld(normalTS,TBN));
		float4 albedo = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,input.uv)*_basicColor ;
		float occlusion = _occlusion * SAMPLE_TEXTURE2D(_occlusionMap,sampler_occlusionMap,input.uv).x;
		float roughness = _roughness * SAMPLE_TEXTURE2D(_roughnessMap,sampler_roughnessMap,input.uv).x;
		float metallic = _metallic * SAMPLE_TEXTURE2D(_MetallicMap,sampler_MetallicMap,input.uv).x;
//SurfaceData
		SurfaceData sData = (SurfaceData)0;
		sData.albedo = albedo.xyz;
		sData.alpha =albedo.a;
		sData.occlusion = occlusion;
		sData.normalTS = normalTS;
		sData.emission = 0;
		sData.metallic = metallic;
		sData.smoothness = 1-roughness;
		sData.specular = 0.0;
		sData.clearCoatMask = 0.0h;
		sData.clearCoatSmoothness = 0.0h;

//InputData
		InputData iData = (InputData)0;
		iData.positionWS = input.positionWS;
		iData.normalWS = normalWS;
		iData.viewDirectionWS = viewDirWS;
		iData.fogCoord = input.fogFactorAndVertexLight.x;
		iData.vertexLighting = input.fogFactorAndVertexLight.yzw;
		#if defined(DYNAMICLIGHTMAP_ON)
			iData.bakedGI = SAMPLE_GI(input.lightmapUV,input.dynamicLightmapUV,input.vertexSH,normalWS);
		#else 
			iData.bakedGI = SAMPLE_GI(input.lightmapUV,input.vertexSH,normalWS);
		#endif
		iData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
		iData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
		iData.shadowCoord = shadowCoord;
		half4 color = UniversalFragmentPBR(iData, sData);

		return color ;
	#endif
}