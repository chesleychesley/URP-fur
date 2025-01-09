Shader "chesleyURP/fountain"
{
    Properties
    {
        //[Header(Basic)]只是为了在编写时分辨 不显示到材质面板
		[KeywordEnum(waterface,waterfalls,opaque)]_UseType("Type",float) = 0.0
		_NormalMap("rippleMap",2D) = "white"{}
		[HDR]_basicColor("BaseColor",color) = (1,1,1,1)

		//[Header(Opaque)]
		[NoScaleOffset]_bumpMap("BumpMap",2D) = "bump"{}
		_bumpScale("bumpScale",range(1,10)) = 1
		_occlusionMap("occlusionMap",2D) = "white"{}
		_occlusion("Occlusion",range(0,1)) = 0.5
		_roughnessMap("roughnessMap",2D) = "white"{}
		_roughness("roughness",range(0,1)) = 0.5
		_MetallicMap("MetallicMap",2D) = "white"{}
		_metallic("Metallic",range(0,1)) = 0.5

		//[Header(watersurface]
		_noiseStrength("NoiseStrength",range(0.1,5)) = 1
		_rippleAmount("rippleAmount",range(0.1,5))= 1
		_alpha("Alpha",range(0,1)) = 0.5
		_fresnelOffset("fresnelOffset",range(-1,1)) = 0
		_shadowAttenOffsetFace("ShadowAttenOffsetFace",range(0,1)) = 0.5

		//[Header(waterfalls)]
		_FallingSpeed("FallingSpeed",range(0.1,20)) = 1
		_noiseStrengthFalls("NoiseControl",range(0.1,5)) = 1
		_positionOffset("positionOffset",range(-1,1)) = 0
		_alphaFallsOffset("alphaFallsOffset",range(-1,1)) = 0
		_shadowAttenOffsetFall("ShadowAttenOffsetFall",range(0,1)) = 0.5


		[Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend("SourceBlendMode",float) = 2 
		[Enum(UnityEngine.Rendering.BlendMode)]_DstBlend("DstBlendMode",float) = 2 

    }
    SubShader
    {
        Tags { "RenderType"="Opaque"
				"RenderPipeline" = "UniversalPipeline"
				"Queue" = "Geometry"
				}
		HLSLINCLUDE
		#include "FountainInput.hlsl"

		ENDHLSL
        Pass
        {
            Tags{"LightMode" = "UniversalForward"}

			Blend [_SrcBlend][_DstBlend]
            HLSLPROGRAM
			#pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
	        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile  _SHADOWS_SOFT
			#pragma multi_compile _ _ADDITIONAL_LIGHTS
			#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION


			#pragma shader_feature_local _ _USETYPE_WATERFACE _USETYPE_WATERFALLS _USETYPE_OPAQUE
			#pragma vertex vert
            #pragma fragment frag

			#include "FountainPass.hlsl"
			ENDHLSL
        }
		

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On

            ColorMask 0


            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------


            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}



            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------


            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex LitGBufferPassVertex
            #pragma fragment LitGBufferPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitGBufferPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0


            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------



            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        // This pass is used when drawing to a _CameraNormalsTexture texture
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On


            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment



            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit

            #pragma shader_feature EDITOR_VISUALIZATION


            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"


            ENDHLSL
        }
    }

	CustomEditor"fountainGUI"
}

