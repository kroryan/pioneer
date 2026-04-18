/**
 * Bloom shader
 * by Ioxa
 *
 * Adds a glow/bloom effect to bright areas of the scene.
 */

#include "ReShade.fxh"

uniform float BloomThreshold <
	ui_label = "Bloom Threshold";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_tooltip = "Pixels brighter than this value get bloom applied.";
> = 0.8;

uniform float BloomAmount <
	ui_label = "Bloom Amount";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_tooltip = "Amount of bloom to apply.";
> = 0.6;

uniform float BloomSaturation <
	ui_label = "Bloom Saturation";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 2.0;
	ui_tooltip = "Saturation of the bloom effect.";
> = 1.0;

uniform float3 BloomTint <
	ui_label = "Bloom Tint";
	ui_type = "color";
	ui_tooltip = "Color tint of the bloom.";
> = float3(1.0, 1.0, 1.0);

texture BloomTex { Width = BUFFER_WIDTH / 2; Height = BUFFER_HEIGHT / 2; Format = RGBA16F; };
sampler BloomSampler { Texture = BloomTex; AddressU = CLAMP; AddressV = CLAMP; MipFilter = LINEAR; MinFilter = LINEAR; MagFilter = LINEAR; };

texture BloomTex2 { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = RGBA16F; };
sampler BloomSampler2 { Texture = BloomTex2; AddressU = CLAMP; AddressV = CLAMP; MipFilter = LINEAR; MinFilter = LINEAR; MagFilter = LINEAR; };

float4 BloomExtract(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	float4 color = tex2D(ReShade::BackBuffer, texcoord);
	float brightness = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
	float4 bloom = max(0, color - BloomThreshold);
	return bloom;
}

float4 BloomBlurH(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	float4 color = 0;
	float2 offset = float2(ReShade::PixelSize.x * 2.0, 0.0);

	color += tex2D(BloomSampler, texcoord - offset * 3.0) * 0.0625;
	color += tex2D(BloomSampler, texcoord - offset * 2.0) * 0.125;
	color += tex2D(BloomSampler, texcoord - offset * 1.0) * 0.25;
	color += tex2D(BloomSampler, texcoord)                 * 0.125;
	color += tex2D(BloomSampler, texcoord + offset * 1.0) * 0.25;
	color += tex2D(BloomSampler, texcoord + offset * 2.0) * 0.125;
	color += tex2D(BloomSampler, texcoord + offset * 3.0) * 0.0625;

	return color;
}

float4 BloomBlurV(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	float4 color = 0;
	float2 offset = float2(0.0, ReShade::PixelSize.y * 2.0);

	color += tex2D(BloomSampler2, texcoord - offset * 3.0) * 0.0625;
	color += tex2D(BloomSampler2, texcoord - offset * 2.0) * 0.125;
	color += tex2D(BloomSampler2, texcoord - offset * 1.0) * 0.25;
	color += tex2D(BloomSampler2, texcoord)                 * 0.125;
	color += tex2D(BloomSampler2, texcoord + offset * 1.0) * 0.25;
	color += tex2D(BloomSampler2, texcoord + offset * 2.0) * 0.125;
	color += tex2D(BloomSampler2, texcoord + offset * 3.0) * 0.0625;

	return color;
}

float4 BloomCombine(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	float4 color = tex2D(ReShade::BackBuffer, texcoord);
	float4 bloom = tex2D(BloomSampler, texcoord);

	// Tint the bloom
	bloom.rgb *= BloomTint;

	// Adjust bloom saturation
	float bloomLuma = dot(bloom.rgb, float3(0.2126, 0.7152, 0.0722));
	bloom.rgb = lerp(bloomLuma.xxx, bloom.rgb, BloomSaturation);

	color.rgb += bloom.rgb * BloomAmount;

	return saturate(color);
}

technique Bloom
{
	pass ExtractBloom
	{
		VertexShader = PostProcessVS;
		PixelShader  = BloomExtract;
		RenderTarget = BloomTex;
	}
	pass BlurHorizontal
	{
		VertexShader = PostProcessVS;
		PixelShader  = BloomBlurH;
		RenderTarget = BloomTex2;
	}
	pass BlurVertical
	{
		VertexShader = PostProcessVS;
		PixelShader  = BloomBlurV;
		RenderTarget = BloomTex;
	}
	pass CombineBloom
	{
		VertexShader = PostProcessVS;
		PixelShader  = BloomCombine;
	}
}
