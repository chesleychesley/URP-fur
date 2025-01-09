#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

half remap(half x, half t1, half t2, half s1, half s2)
{
	return (x - t1) / (t2 - t1) * (s2 - s1) + s1;
}
float rand(float3 seed)
			{
				float f = sin(dot(seed, float3(127.1, 337.1, 256.2)));
				f = -1 + 2 * frac(f * 43785.5453123);
				return f;
			}
float pow5(float n){
	return n*n*n*n*n;
}

float3 Ripple(float4 decodeMap,float3 positionWS){//水面波纹的法线
	float range = decodeMap.a;

	float timeApp = decodeMap.z;//z通道为噪波
	int boolo = step(0.001,decodeMap.a);//判断是不是水波范围,a通道为涟漪范围
	decodeMap.xy = decodeMap.xy *2 -1;//范围映射到-1到1
	float dropFac = frac(range + _Time.x);//随时间波动
	
	float height1 = range* sin(20*_rippleAmount*dropFac*PI +timeApp*10*_noiseStrength)*boolo;//乘以range是为了达到淡出的效果

	return float3(decodeMap.xy*(height1),1);

}

float3 Getreflection(float3 reflectDirWS){
	half4 enCol = SAMPLE_TEXTURECUBE(unity_SpecCube0,samplerunity_SpecCube0,reflectDirWS);
	half3 envHDRCol = DecodeHDREnvironment(enCol,unity_SpecCube0_HDR);
	return envHDRCol;
}

