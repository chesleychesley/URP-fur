Shader "chesleyURP/fur1"
{
    Properties
    {
        [KeywordEnum(Body,Other)]_RenderType("RenderType",float) = 0.0
		[KeywordEnum(Isotropy,Anisotropy)] _BRDFModel("BRDFModel",float) = 0.0
		//[Header(Basic)][Space]
		_baseColor("baseColor", Color) = (1.0, 1.0, 1.0, 1)
		[NoScaleOffset]_baseMap("baseMap", 2D) = "white" {}

		//[Header(Aniso)]
		_specularColor("SpecularColor",color) = (1,1,1,1)
		_rougness("roughness",range(0,1)) = 0.5
		_metallic("metallic",range(0,1)) = 0
		_Anisotropy("Anisotropy",range(-1,1))= 0.5
		_normalAniso("normalAniso",range(-1,1))= 0.5
		_Occlusion("Occlusion", Range(0.0, 1.0)) = 0.5
		_occlusionMap("occlusionMap",2D) = "white" {}
		//[Header(Fur)][Space]
		
		_FurMap("FurMap", 2D) = "white" {}
		[Normal] _NormalMap("Normal", 2D) = "bump" {}
		_NormalScale("NormalScale", Range(0.0, 2.0)) = 1.0
		[IntRange] _ShellAmount("ShellAmount", Range(1, 15)) = 14
		_ShellStep("ShellStep", Range(0.0, 0.01)) = 0.001
		_AlphaCutout("AlphaCutout", Range(0.0, 1.0)) = 0.2
		_FurScale("FurScale", Range(0.0, 10.0)) = 1.0
		
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" 
				"RenderPipeline" = "UniversalPipeline" 
				"UniversalMaterialType" = "Lit"
				"IgnoreProjector" = "True" }
        LOD 100

        Pass
        {
            Name "ForwardLit"
			Tags { "LightMode" = "UniversalForward" }

			ZWrite On
			Cull Back
			HLSLPROGRAM
			// URP
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile _ _SHADOWS_SOFT
			#pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
			#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION

			// Unity
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile_fog

			//shader feature
			#pragma shader_feature_local _ _RENDERTYPE_BODY _RENDERTYPE_OTHER
			#pragma shader_feature_local _ _BRDFMODEL_ISOTROPY _BRDFMODEL_ANISOTROPY

			#pragma exclude_renderers gles gles3 glcore
			//#pragma multi_compile _ DRAW_ORIG_POLYGON
			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geom 

				
			#include "BodyForwardPass.hlsl"

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

	CustomEditor "furGUI"
}
