#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Input.hlsl"
#include "anisotropy.hlsl"


struct Attributes{
	float4 positionOS : POSITION;
	float3 normalOS : NORMAL;
	float4 tangentOS : TANGENT;
	float2 uv: TEXCOORD0;
	float2 lightmapUV : TEXCOORD1;
	float4 vertexColor : COLOR;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings{
	float4 positionCS: SV_POSITION;
	float3 positionWS: TEXCOORD0;
	float3 normalWS: TEXCOORD1;
	float3 tangentWS: TEXCOORD2;
	float2 uv: TEXCOORD3;
	DECLARE_LIGHTMAP_OR_SH(lightmapUV,vertexSH,4);
	float4 fogFactorAndVertexLight : TEXCOORD5;
#ifdef _RENDERTYPE_BODY
	float2 layerAndVColor  : TEXCOORD6;
#endif

};


Attributes vert(Attributes input)
{
    return input;
}


void AppendShellVertex(inout TriangleStream<Varyings> stream, Attributes input, int index)
{
	Varyings output = (Varyings)0;
	VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
	VertexNormalInputs NormalInput = GetVertexNormalInputs(input.normalOS,input.tangentOS);
	float3 viewDirWS = normalize(GetCameraPositionWS()-vertexInput.positionWS);

#ifdef _RENDERTYPE_BODY
	float3 shellDir = normalize(NormalInput.normalWS);
	output.positionWS = vertexInput.positionWS + shellDir * _ShellStep * index;
	output.layerAndVColor.x = (float)index / _ShellAmount;
	output.layerAndVColor.y = input.vertexColor.x;
#else 
	output.positionWS = vertexInput.positionWS;
#endif
	output.positionCS = TransformWorldToHClip(output.positionWS);
	output.uv = input.uv;
	output.normalWS = NormalInput.normalWS;
	output.tangentWS = NormalInput.tangentWS;


	float3 vertexLight = VertexLighting(vertexInput.positionWS,NormalInput.normalWS);
	float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
	output.fogFactorAndVertexLight = float4(fogFactor,vertexLight);

	OUTPUT_LIGHTMAP_UV(input.lightmapUV,unity_LightmapST,output.lightmapUV);
	OUTPUT_SH(output.normalWS.xyz,output.vertexSH);

	stream.Append(output);
}

#ifdef _RENDERTYPE_BODY
	[maxvertexcount(42)]
#else
	[maxvertexcount(3)]
#endif
void geom(triangle Attributes input[3],inout TriangleStream<Varyings>stream){
#ifdef _RENDERTYPE_BODY
	float value = input[0].vertexColor.x;
	int iteration = min(14,max(1,floor(_ShellAmount*value)+1));
	[Loop]for(float i =0; i < iteration; i++){
		[unroll]for(float j =0; j<3; ++j){
			AppendShellVertex(stream,input[j],i);

		}
		stream.RestartStrip();
	}
#else
	AppendShellVertex(stream,input[0],1);
	AppendShellVertex(stream,input[1],1);
	AppendShellVertex(stream,input[2],1);
#endif

}

float4 frag(Varyings input): SV_Target {

	//公用数据
	float3 viewDirWS = normalize(GetCameraPositionWS()-input.positionWS);
	float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,input.uv),_NormalScale);
	float3 bitangent = normalize(cross(input.normalWS,input.tangentWS)*viewDirWS.y);
	float3x3 TBN = float3x3(input.tangentWS,bitangent,input.normalWS);
	float3 normalWS = normalize(TransformTangentToWorld(normalTS,TBN));
	float occlusionMap = SAMPLE_TEXTURE2D(_occlusionMap,sampler_occlusionMap,input.uv).r;
	
	float3 reflectDirWS = reflect(-viewDirWS,normalWS);
	float4 albedo = SAMPLE_TEXTURE2D(_baseMap,sampler_baseMap,input.uv)*_baseColor;
	#if (defined(_MAIN_LIGHT_SHADOWS) || defined(_MAIN_LIGHT_SHADOWS_CASCADE) || defined(_MAIN_LIGHT_SHADOWS_SCREEN)) && !defined(_RECEIVE_SHADOWS_OFF)
		float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
	#else
		float4 shadowCoord = float4(0, 0, 0, 0);
	#endif
	
	//身体部分
#ifdef _RENDERTYPE_BODY
	float2 furUV = input.uv * _FurScale;
	float4 furColor = SAMPLE_TEXTURE2D(_FurMap,sampler_FurMap,furUV);
	float alpha = furColor.r *(1.0-input.layerAndVColor.x);//越底层的不透明度越高，越表层的越高
	if (input.layerAndVColor.x>0.0 && alpha < _AlphaCutout ) discard; //选择性地剔除一些物体
	float occlusion = lerp(1.0-_Occlusion,1.0,input.layerAndVColor.x);
	
	

		//isotropy
	#ifdef _BRDFMODEL_ISOTROPY
		SurfaceData sData = (SurfaceData)0;

		sData.occlusion = occlusion;//越往顶层数值越大
		sData.albedo =albedo.xyz ;
		sData.alpha = 1;
		sData.normalTS = normalTS;
		sData.emission = 0;
		sData.metallic = _metallic;
		sData.smoothness = _rougness;
		sData.specular = 0.0;
		sData.clearCoatMask = 0.0h;
		sData.clearCoatSmoothness = 0.0h;

		InputData iData = (InputData)0;
		iData.positionWS = input.positionWS;
		iData.normalWS = normalWS;
		iData.viewDirectionWS = viewDirWS;
		iData.shadowCoord = shadowCoord;

		iData.fogCoord = input.fogFactorAndVertexLight.x;
		iData.vertexLighting = input.fogFactorAndVertexLight.yzw;
		#if defined(DYNAMICLIGHTMAP_ON)
			iData.bakedGI = SAMPLE_GI(input.lightmapUV,input.dynamicLightmapUV,input.vertexSH,normalWS);
		#else 
			iData.bakedGI = SAMPLE_GI(input.lightmapUV,input.vertexSH,normalWS);
		#endif
		iData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);

		float4 isoColor = UniversalFragmentPBR(iData,sData);

		isoColor.rgb = MixFog(isoColor.rgb,iData.fogCoord);
	
		return isoColor;
	#else 
		//anisotropy
		float4 shadowmask = SAMPLE_SHADOWMASK(input.lightmapUV);
		half3 anisoColor = PBRaniso(albedo.xyz,_specularColor.xyz,_rougness,_metallic,occlusion,input.positionWS,normalTS,TBN,reflectDirWS,viewDirWS,_Anisotropy,_normalAniso,shadowmask);
		return half4(anisoColor,1.0);
	#endif

#else
	
	#ifdef _BRDFMODEL_ISOTROPY
		SurfaceData sData = (SurfaceData)0;

		sData.occlusion = _Occlusion*occlusionMap;
		sData.albedo =albedo.xyz ;
		sData.alpha = 1;
		sData.normalTS = normalTS;
		sData.emission = 0;
		sData.metallic = _metallic;
		sData.smoothness = _rougness;
		sData.specular = 0.0;
		sData.clearCoatMask = 0.0h;
		sData.clearCoatSmoothness = 0.0h;

		InputData iData = (InputData)0;
		iData.positionWS = input.positionWS;
		iData.normalWS = normalWS;
		iData.viewDirectionWS = viewDirWS;
		iData.shadowCoord = shadowCoord;

		iData.fogCoord = input.fogFactorAndVertexLight.x;
		iData.vertexLighting = input.fogFactorAndVertexLight.yzw;
		#if defined(DYNAMICLIGHTMAP_ON)
			iData.bakedGI = SAMPLE_GI(input.lightmapUV,input.dynamicLightmapUV,input.vertexSH,normalWS);
		#else 
			iData.bakedGI = SAMPLE_GI(input.lightmapUV,input.vertexSH,normalWS);
		#endif
		iData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);

		float4 isoColor = UniversalFragmentPBR(iData,sData);

		isoColor.rgb = MixFog(isoColor.rgb,iData.fogCoord);
	
		return isoColor;
	#else
		float occlusion = _Occlusion*occlusionMap;
		float4 shadowmask = SAMPLE_SHADOWMASK(input.lightmapUV);
		half3 anisoColor = PBRaniso(albedo.xyz,_specularColor.xyz,_rougness,_metallic,occlusion,input.positionWS,normalTS,TBN,reflectDirWS,viewDirWS,_Anisotropy,_normalAniso,shadowmask);
		return half4(anisoColor,1.0);
	#endif
		
#endif
}
