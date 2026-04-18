/*=============================================================================

	ReShade 4 effect file
	github.com/martymcmodding

	Support me:
   		paypal.me/mcflypg
   		patreon.com/mcflypg

    Bloom
    by Pascal Gilcher (Marty McFly)

    * Unauthorized copying of this file, via any medium is strictly prohibited
    * Proprietary and confidential
    * This file is provided for personal use only.

=============================================================================*/

#pragma once

/*=============================================================================
	Preprocessor settings
=============================================================================*/

#ifndef BLOOM_MAX_MIP
 #define BLOOM_MAX_MIP 7
#endif

#ifndef BLOOM_QUALITY_0
 #define BLOOM_QUALITY_0 2
#endif

/*=============================================================================
	UI Uniforms
=============================================================================*/

uniform float BLOOM_INTENSITY <
	ui_type = "slider";
	ui_label = "Bloom Intensity";
	ui_tooltip = "Scales the overall intensity of the bloom effect.";
	ui_min = 0.0; ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;

uniform float BLOOM_CURVE <
	ui_type = "slider";
	ui_label = "Bloom Curve";
	ui_tooltip = "Controls the response curve of the bloom. Higher values produce bloom only from very bright sources.";
	ui_min = 0.0; ui_max = 4.0;
	ui_step = 0.001;
> = 1.5;

uniform float BLOOM_SATURATION <
	ui_type = "slider";
	ui_label = "Bloom Saturation";
	ui_tooltip = "Adjusts the saturation of the bloom colors.";
	ui_min = 0.0; ui_max = 2.0;
	ui_step = 0.001;
> = 1.0;

uniform float BLOOM_TONEMAP_COMPRESSION <
	ui_type = "slider";
	ui_label = "Tonemap Compression";
	ui_tooltip = "Compresses the bloom tonemapper output to simulate HDR behavior.";
	ui_min = 0.0; ui_max = 20.0;
	ui_step = 0.001;
> = 4.0;

uniform float BLOOM_LAYER_MULT_1 <
	ui_type = "slider";
	ui_label = "Layer Multiplier 1 (Smallest)";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;

uniform float BLOOM_LAYER_MULT_2 <
	ui_type = "slider";
	ui_label = "Layer Multiplier 2";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;

uniform float BLOOM_LAYER_MULT_3 <
	ui_type = "slider";
	ui_label = "Layer Multiplier 3";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;

uniform float BLOOM_LAYER_MULT_4 <
	ui_type = "slider";
	ui_label = "Layer Multiplier 4";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;

uniform float BLOOM_LAYER_MULT_5 <
	ui_type = "slider";
	ui_label = "Layer Multiplier 5";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;

uniform float BLOOM_LAYER_MULT_6 <
	ui_type = "slider";
	ui_label = "Layer Multiplier 6";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;

uniform float BLOOM_LAYER_MULT_7 <
	ui_type = "slider";
	ui_label = "Layer Multiplier 7 (Largest)";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;

uniform float BLOOM_ADAPT_STRENGTH <
	ui_type = "slider";
	ui_label = "Adaptation Strength";
	ui_tooltip = "Strength of the eye adaptation / auto exposure effect.";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.001;
> = 0.5;

uniform float BLOOM_ADAPT_SPEED <
	ui_type = "slider";
	ui_label = "Adaptation Speed";
	ui_tooltip = "Speed of eye adaptation.";
	ui_min = 0.001; ui_max = 1.0;
	ui_step = 0.001;
> = 0.2;

uniform float BLOOM_ADAPT_EXPOSURE <
	ui_type = "slider";
	ui_label = "Adaptation Exposure Bias";
	ui_min = -2.0; ui_max = 2.0;
	ui_step = 0.001;
> = 0.0;

/*=============================================================================
	Textures, Samplers
=============================================================================*/

#include "ReShade.fxh"

#define BLOOM_CONST_LOG2 1.4426950408

texture2D BLOOM_DownTex0  { Width = BUFFER_WIDTH / 2;   Height = BUFFER_HEIGHT / 2;   Format = RGBA16F; };
texture2D BLOOM_DownTex1  { Width = BUFFER_WIDTH / 4;   Height = BUFFER_HEIGHT / 4;   Format = RGBA16F; };
texture2D BLOOM_DownTex2  { Width = BUFFER_WIDTH / 8;   Height = BUFFER_HEIGHT / 8;   Format = RGBA16F; };
texture2D BLOOM_DownTex3  { Width = BUFFER_WIDTH / 16;  Height = BUFFER_HEIGHT / 16;  Format = RGBA16F; };
texture2D BLOOM_DownTex4  { Width = BUFFER_WIDTH / 32;  Height = BUFFER_HEIGHT / 32;  Format = RGBA16F; };
texture2D BLOOM_DownTex5  { Width = BUFFER_WIDTH / 64;  Height = BUFFER_HEIGHT / 64;  Format = RGBA16F; };
texture2D BLOOM_DownTex6  { Width = BUFFER_WIDTH / 128; Height = BUFFER_HEIGHT / 128; Format = RGBA16F; };
texture2D BLOOM_AdaptTex  { Width = 1;                  Height = 1;                   Format = R16F;    };
texture2D BLOOM_PrevAdaptTex { Width = 1;               Height = 1;                   Format = R16F;    };

sampler2D sBloom_DownTex0  { Texture = BLOOM_DownTex0;  AddressU = BORDER; AddressV = BORDER; };
sampler2D sBloom_DownTex1  { Texture = BLOOM_DownTex1;  AddressU = BORDER; AddressV = BORDER; };
sampler2D sBloom_DownTex2  { Texture = BLOOM_DownTex2;  AddressU = BORDER; AddressV = BORDER; };
sampler2D sBloom_DownTex3  { Texture = BLOOM_DownTex3;  AddressU = BORDER; AddressV = BORDER; };
sampler2D sBloom_DownTex4  { Texture = BLOOM_DownTex4;  AddressU = BORDER; AddressV = BORDER; };
sampler2D sBloom_DownTex5  { Texture = BLOOM_DownTex5;  AddressU = BORDER; AddressV = BORDER; };
sampler2D sBloom_DownTex6  { Texture = BLOOM_DownTex6;  AddressU = BORDER; AddressV = BORDER; };
sampler2D sBloom_AdaptTex  { Texture = BLOOM_AdaptTex;  };
sampler2D sBloom_PrevAdaptTex { Texture = BLOOM_PrevAdaptTex; };

/*=============================================================================
	Vertex Shader
=============================================================================*/

void VS_PostProcess(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TexCoord)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/*=============================================================================
	Downsample kernel
=============================================================================*/

float4 DownsampleKernel(sampler2D tex, float2 uv, float2 pixelsize)
{
	float4 result = 0;
	result += tex2D(tex, uv + float2(-1.0, -1.0) * pixelsize) * 0.25;
	result += tex2D(tex, uv + float2( 1.0, -1.0) * pixelsize) * 0.25;
	result += tex2D(tex, uv + float2(-1.0,  1.0) * pixelsize) * 0.25;
	result += tex2D(tex, uv + float2( 1.0,  1.0) * pixelsize) * 0.25;
	return result;
}

float4 UpsampleKernel(sampler2D tex, float2 uv, float2 pixelsize, float weight)
{
	float4 result = 0;
	result += tex2D(tex, uv + float2(-1.0, -1.0) * pixelsize);
	result += tex2D(tex, uv + float2( 0.0, -1.0) * pixelsize) * 2.0;
	result += tex2D(tex, uv + float2( 1.0, -1.0) * pixelsize);
	result += tex2D(tex, uv + float2(-1.0,  0.0) * pixelsize) * 2.0;
	result += tex2D(tex, uv)                                   * 4.0;
	result += tex2D(tex, uv + float2( 1.0,  0.0) * pixelsize) * 2.0;
	result += tex2D(tex, uv + float2(-1.0,  1.0) * pixelsize);
	result += tex2D(tex, uv + float2( 0.0,  1.0) * pixelsize) * 2.0;
	result += tex2D(tex, uv + float2( 1.0,  1.0) * pixelsize);
	return result / 16.0 * weight;
}

/*=============================================================================
	Pixel Shaders
=============================================================================*/

void PS_Prepass(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	float4 color = tex2D(ReShade::BackBuffer, uv);

	// Extract bright areas
	float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
	float adaptation = tex2Dfetch(sBloom_AdaptTex, int4(0, 0, 0, 0)).r;
	float exposure = exp2(BLOOM_ADAPT_EXPOSURE) / max(1e-5, adaptation);
	color.rgb *= exposure * BLOOM_ADAPT_STRENGTH + (1.0 - BLOOM_ADAPT_STRENGTH);

	color.rgb = pow(max(0, color.rgb), BLOOM_CURVE);

	// Saturation
	float luma = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
	color.rgb = lerp(luma.xxx, color.rgb, BLOOM_SATURATION);

	result = color;
}

void PS_Down1(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	result = DownsampleKernel(ReShade::BackBuffer, uv, ReShade::PixelSize) * BLOOM_LAYER_MULT_1;
}

void PS_Down2(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	result = DownsampleKernel(sBloom_DownTex0, uv, ReShade::PixelSize * 2.0) * BLOOM_LAYER_MULT_2;
}

void PS_Down3(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	result = DownsampleKernel(sBloom_DownTex1, uv, ReShade::PixelSize * 4.0) * BLOOM_LAYER_MULT_3;
}

void PS_Down4(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	result = DownsampleKernel(sBloom_DownTex2, uv, ReShade::PixelSize * 8.0) * BLOOM_LAYER_MULT_4;
}

void PS_Down5(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	result = DownsampleKernel(sBloom_DownTex3, uv, ReShade::PixelSize * 16.0) * BLOOM_LAYER_MULT_5;
}

void PS_Down6(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	result = DownsampleKernel(sBloom_DownTex4, uv, ReShade::PixelSize * 32.0) * BLOOM_LAYER_MULT_6;
}

void PS_Down7(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	result = DownsampleKernel(sBloom_DownTex5, uv, ReShade::PixelSize * 64.0) * BLOOM_LAYER_MULT_7;
}

void PS_AdaptStore(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	float current = tex2D(sBloom_DownTex6, float2(0.5, 0.5)).r;
	float prev = tex2Dfetch(sBloom_PrevAdaptTex, int4(0, 0, 0, 0)).r;
	result = lerp(prev, current, BLOOM_ADAPT_SPEED);
}

void PS_Up6(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	result = tex2D(sBloom_DownTex5, uv) + UpsampleKernel(sBloom_DownTex6, uv, ReShade::PixelSize * 64.0, 1.0);
}

void PS_Up5(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	result = tex2D(sBloom_DownTex4, uv) + UpsampleKernel(sBloom_DownTex5, uv, ReShade::PixelSize * 32.0, 1.0);
}

void PS_Up4(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	result = tex2D(sBloom_DownTex3, uv) + UpsampleKernel(sBloom_DownTex4, uv, ReShade::PixelSize * 16.0, 1.0);
}

void PS_Up3(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	result = tex2D(sBloom_DownTex2, uv) + UpsampleKernel(sBloom_DownTex3, uv, ReShade::PixelSize * 8.0, 1.0);
}

void PS_Up2(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	result = tex2D(sBloom_DownTex1, uv) + UpsampleKernel(sBloom_DownTex2, uv, ReShade::PixelSize * 4.0, 1.0);
}

void PS_Up1(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	result = tex2D(sBloom_DownTex0, uv) + UpsampleKernel(sBloom_DownTex1, uv, ReShade::PixelSize * 2.0, 1.0);
}

void PS_Combine(in float4 pos : SV_Position, in float2 uv : TexCoord, out float4 result : SV_Target)
{
	float4 color = tex2D(ReShade::BackBuffer, uv);
	float4 bloom = UpsampleKernel(sBloom_DownTex0, uv, ReShade::PixelSize, BLOOM_INTENSITY);

	// Tonemap compression
	bloom.rgb = bloom.rgb / (bloom.rgb + BLOOM_TONEMAP_COMPRESSION);

	color.rgb += bloom.rgb;
	result = color;
}

/*=============================================================================
	Techniques
=============================================================================*/

technique Bloom
<
	ui_label = "qUINT Bloom";
	ui_tooltip = "High quality bloom effect with eye adaptation and multi-layer blending.";
>
{
	pass Down1 { VertexShader = VS_PostProcess; PixelShader = PS_Down1; RenderTarget = BLOOM_DownTex0; }
	pass Down2 { VertexShader = VS_PostProcess; PixelShader = PS_Down2; RenderTarget = BLOOM_DownTex1; }
	pass Down3 { VertexShader = VS_PostProcess; PixelShader = PS_Down3; RenderTarget = BLOOM_DownTex2; }
	pass Down4 { VertexShader = VS_PostProcess; PixelShader = PS_Down4; RenderTarget = BLOOM_DownTex3; }
	pass Down5 { VertexShader = VS_PostProcess; PixelShader = PS_Down5; RenderTarget = BLOOM_DownTex4; }
	pass Down6 { VertexShader = VS_PostProcess; PixelShader = PS_Down6; RenderTarget = BLOOM_DownTex5; }
	pass Down7 { VertexShader = VS_PostProcess; PixelShader = PS_Down7; RenderTarget = BLOOM_DownTex6; }
	pass AdaptStore { VertexShader = VS_PostProcess; PixelShader = PS_AdaptStore; RenderTarget = BLOOM_AdaptTex; }
	pass Up6  { VertexShader = VS_PostProcess; PixelShader = PS_Up6;  RenderTarget = BLOOM_DownTex5; }
	pass Up5  { VertexShader = VS_PostProcess; PixelShader = PS_Up5;  RenderTarget = BLOOM_DownTex4; }
	pass Up4  { VertexShader = VS_PostProcess; PixelShader = PS_Up4;  RenderTarget = BLOOM_DownTex3; }
	pass Up3  { VertexShader = VS_PostProcess; PixelShader = PS_Up3;  RenderTarget = BLOOM_DownTex2; }
	pass Up2  { VertexShader = VS_PostProcess; PixelShader = PS_Up2;  RenderTarget = BLOOM_DownTex1; }
	pass Up1  { VertexShader = VS_PostProcess; PixelShader = PS_Up1;  RenderTarget = BLOOM_DownTex0; }
	pass Combine { VertexShader = VS_PostProcess; PixelShader = PS_Combine; }
}
