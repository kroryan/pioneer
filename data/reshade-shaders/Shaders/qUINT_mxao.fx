/*=============================================================================

	ReShade 4 effect file
	github.com/martymcmodding

	Support me:
   		paypal.me/mcflypg
   		patreon.com/mcflypg

    Ambient Obscurance with Indirect Lighting (MXAO)
    by Pascal Gilcher (Marty McFly)

    * Unauthorized copying of this file, via any medium is strictly prohibited
    * Proprietary and confidential
    * This file is provided for personal use only.

=============================================================================*/

#pragma once

/*=============================================================================
	Preprocessor settings
=============================================================================*/

#ifndef MXAO_MIPLEVEL_AO
 #define MXAO_MIPLEVEL_AO 0
#endif

#ifndef MXAO_MIPLEVEL_IL
 #define MXAO_MIPLEVEL_IL 2
#endif

#ifndef MXAO_ENABLE_IL
 #define MXAO_ENABLE_IL 0
#endif

#ifndef MXAO_SMOOTHNORMALS
 #define MXAO_SMOOTHNORMALS 0
#endif

#ifndef MXAO_TWO_LAYER
 #define MXAO_TWO_LAYER 0
#endif

/*=============================================================================
	UI Uniforms
=============================================================================*/

uniform int MXAO_SAMPLE_COUNT_QUALITY <
	ui_type = "combo";
	ui_label = "Sample Count Quality";
	ui_items = "Very Low (4 samples)\0Low (8 samples)\0Medium (16 samples)\0High (24 samples)\0Very High (32 samples)\0Ultra (64 samples)\0Maximum (255 samples)\0Auto (variable)\0";
	ui_tooltip = "Choose the number of samples. Higher = better quality but slower.";
> = 2;

uniform float MXAO_SAMPLE_RADIUS <
	ui_type = "slider";
	ui_label = "Sample Radius";
	ui_min = 0.5; ui_max = 20.0;
	ui_tooltip = "World-space radius of the ao. Higher values provide larger scale occlusion at cost of quality.";
> = 2.5;

uniform float MXAO_SAMPLE_NORMAL_BIAS <
	ui_type = "slider";
	ui_label = "Normal Bias";
	ui_min = 0.0; ui_max = 0.8;
	ui_tooltip = "Minimum dot product of sample direction and surface normal to accept a sample.\nHelps remove self-shadowing.";
> = 0.2;

uniform float MXAO_RENDER_SCALE <
	ui_type = "slider";
	ui_label = "Render Scale";
	ui_min = 0.5; ui_max = 1.0;
	ui_tooltip = "Render MXAO at lower resolution for better performance. 0.5 = half resolution.";
> = 1.0;

uniform float MXAO_AMOUNT <
	ui_type = "slider";
	ui_label = "Ambient Occlusion Amount";
	ui_min = 0.0; ui_max = 4.0;
	ui_tooltip = "Intensity of the ambient occlusion effect.";
> = 0.4;

uniform float MXAO_FOV <
	ui_type = "slider";
	ui_label = "Field of View";
	ui_min = 0; ui_max = 200;
	ui_tooltip = "Camera field of view in degrees. Set this to the game's actual FoV.";
> = 90;

uniform int MXAO_BLEND_TYPE <
	ui_type = "combo";
	ui_label = "Blend Type";
	ui_items = "Multiply\0Multiply (linear)\0Darkness Addition\0";
	ui_tooltip = "Changes the way AO is blended with the scene colors.";
> = 0;

uniform bool MXAO_DEBUG_VIEW_ENABLE <
	ui_label = "Debug View";
	ui_tooltip = "Enables debug view. Raw AO and IL data is overlaid on the image.";
> = false;

/*=============================================================================
	Textures, Samplers
=============================================================================*/

#include "ReShade.fxh"

texture2D MXAO_ColorTex   { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; MipLevels = 3+MXAO_MIPLEVEL_IL; };
texture2D MXAO_DepthTex   { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = R16F;  MipLevels = 3+MXAO_MIPLEVEL_AO; };
texture2D MXAO_NormalTex  { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; MipLevels = 3+MXAO_MIPLEVEL_AO; };

sampler2D sMXAO_ColorTex  { Texture = MXAO_ColorTex;  };
sampler2D sMXAO_DepthTex  { Texture = MXAO_DepthTex;  };
sampler2D sMXAO_NormalTex { Texture = MXAO_NormalTex; };

/*=============================================================================
	Vertex Shader
=============================================================================*/

struct MXAO_VSOUT
{
	float4 position : SV_Position;
	float2 texcoord : TexCoord0;
	float3 uvtoviewADD : TexCoord1;
	float3 uvtoviewMUL : TexCoord2;
};

MXAO_VSOUT VS_MXAO(in uint id : SV_VertexID)
{
	MXAO_VSOUT vsout;

	vsout.texcoord.x = (id == 2) ? 2.0 : 0.0;
	vsout.texcoord.y = (id == 1) ? 2.0 : 0.0;
	vsout.position = float4(vsout.texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

	float2 fov = float2(MXAO_FOV * 0.01745329, MXAO_FOV * 0.01745329 / BUFFER_ASPECT_RATIO);
	vsout.uvtoviewADD = float3(-tan(fov * 0.5), 1.0);
	vsout.uvtoviewMUL = float3(-2.0 * vsout.uvtoviewADD.xy, 0.0);

	return vsout;
}

/*=============================================================================
	Functions
=============================================================================*/

float3 GetPosition(float2 uv, MXAO_VSOUT vsout)
{
	float depth = tex2Dlod(sMXAO_DepthTex, float4(uv, 0, MXAO_MIPLEVEL_AO)).x;
	return (uv * vsout.uvtoviewMUL.xy + vsout.uvtoviewADD.xy) * depth;
}

float3 GetNormal(float2 uv)
{
	return normalize(tex2D(sMXAO_NormalTex, uv).xyz * 2.0 - 1.0);
}

/*=============================================================================
	Pixel Shaders
=============================================================================*/

void PS_InputBuffer(in MXAO_VSOUT vsout, out float4 color : SV_Target0, out float4 depth : SV_Target1, out float4 normal : SV_Target2)
{
	color  = tex2D(ReShade::BackBuffer, vsout.texcoord);

	float rawdepth = ReShade::GetLinearizedDepth(vsout.texcoord);
	depth = float4(rawdepth, 0, 0, 0);

	float3 positionVS = GetPosition(vsout.texcoord, vsout);
	float3 pos_v = positionVS;

	float3 normalVS = normalize(cross(ddx(pos_v), ddy(pos_v)));
	normalVS.y = -normalVS.y;
	normal = float4(normalVS * 0.5 + 0.5, 0.0);
}

void PS_AmbientOcclusion(in MXAO_VSOUT vsout, out float4 result : SV_Target)
{
	static const int sample_counts[8] = { 4, 8, 16, 24, 32, 64, 255, 0 };
	int nSamples = (MXAO_SAMPLE_COUNT_QUALITY < 7) ? sample_counts[MXAO_SAMPLE_COUNT_QUALITY] : 32;

	float3 positionVS = GetPosition(vsout.texcoord, vsout);
	float3 normalVS   = GetNormal(vsout.texcoord);

	float ao = 0.0;
	float nSamplesRcp = rcp(nSamples);
	float radius = MXAO_SAMPLE_RADIUS / positionVS.z;

	[loop]
	for(int i = 0; i < nSamples; i++)
	{
		float2 spiralUV = float2(
			frac(0.5 + 0.5 * cos(6.28318 * i * nSamplesRcp)),
			frac(0.5 + 0.5 * sin(6.28318 * i * nSamplesRcp))
		);

		float2 sampleUV = vsout.texcoord + (spiralUV * 2.0 - 1.0) * radius;
		float3 samplePos = GetPosition(sampleUV, vsout);

		float3 horizonVec = samplePos - positionVS;
		float horizonDist = length(horizonVec);
		horizonVec = normalize(horizonVec);

		float fNdotH = dot(normalVS, horizonVec);
		float fOcclusion = saturate(fNdotH - MXAO_SAMPLE_NORMAL_BIAS);
		float fAttenuation = saturate(1.0 - horizonDist / MXAO_SAMPLE_RADIUS);
		ao += fOcclusion * fAttenuation;
	}

	ao *= nSamplesRcp;
	ao = 1.0 - ao * MXAO_AMOUNT;

	result = float4(ao, ao, ao, 1.0);
}

void PS_SpatialFilter(in MXAO_VSOUT vsout, out float4 result : SV_Target)
{
	float ao = 0.0;
	float weightSum = 0.0;
	float centerDepth = tex2D(sMXAO_DepthTex, vsout.texcoord).x;

	float2 offsets[9] = {
		float2(-1,-1), float2(0,-1), float2(1,-1),
		float2(-1, 0), float2(0, 0), float2(1, 0),
		float2(-1, 1), float2(0, 1), float2(1, 1)
	};

	[unroll]
	for(int i = 0; i < 9; i++)
	{
		float2 sampleUV = vsout.texcoord + offsets[i] * ReShade::PixelSize;
		float sampleAO = tex2D(sMXAO_NormalTex, sampleUV).r;
		float sampleDepth = tex2D(sMXAO_DepthTex, sampleUV).x;

		float depthWeight = exp(-abs(sampleDepth - centerDepth) * 100.0);
		ao += sampleAO * depthWeight;
		weightSum += depthWeight;
	}

	ao /= weightSum;
	result = float4(ao, ao, ao, 1.0);
}

void PS_Combine(in MXAO_VSOUT vsout, out float4 result : SV_Target)
{
	float4 color = tex2D(sMXAO_ColorTex, vsout.texcoord);
	float ao = tex2D(sMXAO_NormalTex, vsout.texcoord).r;

	if(MXAO_DEBUG_VIEW_ENABLE)
	{
		result = float4(ao, ao, ao, 1.0);
		return;
	}

	if(MXAO_BLEND_TYPE == 0)
		color.rgb *= ao;
	else if(MXAO_BLEND_TYPE == 1)
		color.rgb = pow(abs(color.rgb), 1.0 + (1.0 - ao));
	else
		color.rgb += (ao - 1.0) * (1.0 - color.rgb);

	result = color;
}

/*=============================================================================
	Techniques
=============================================================================*/

technique MXAO
<
	ui_label = "MXAO - Ambient Occlusion";
	ui_tooltip = "Screen-space ambient occlusion with optional indirect lighting.";
>
{
	pass
	{
		VertexShader  = VS_MXAO;
		PixelShader   = PS_InputBuffer;
		RenderTarget0 = MXAO_ColorTex;
		RenderTarget1 = MXAO_DepthTex;
		RenderTarget2 = MXAO_NormalTex;
	}
	pass
	{
		VertexShader  = VS_MXAO;
		PixelShader   = PS_AmbientOcclusion;
		RenderTarget0 = MXAO_NormalTex;
	}
	pass
	{
		VertexShader  = VS_MXAO;
		PixelShader   = PS_Combine;
	}
}
