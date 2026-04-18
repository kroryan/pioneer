/**
 * Contrast Adaptive Sharpening (CAS)
 * by AMD (ported to ReShade by crosire)
 *
 * MIT License
 */

#include "ReShade.fxh"

uniform float CAS_SHARPNESS <
	ui_type = "slider";
	ui_label = "Sharpness";
	ui_min = 0.0; ui_max = 1.0;
	ui_tooltip = "0 = the sharpened result is the same as the input, 1 = the maximum amount of sharpening.";
> = 0.5;

float3 CASPass(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// Fetch a 3x3 neighborhood around the pixel 'e'.
	//  a b c
	//  d e f
	//  g h i

	float3 a = tex2Doffset(ReShade::BackBuffer, texcoord, int2(-1, -1)).rgb;
	float3 b = tex2Doffset(ReShade::BackBuffer, texcoord, int2( 0, -1)).rgb;
	float3 c = tex2Doffset(ReShade::BackBuffer, texcoord, int2( 1, -1)).rgb;
	float3 d = tex2Doffset(ReShade::BackBuffer, texcoord, int2(-1,  0)).rgb;
	float3 e = tex2D(ReShade::BackBuffer, texcoord).rgb;
	float3 f = tex2Doffset(ReShade::BackBuffer, texcoord, int2( 1,  0)).rgb;
	float3 g = tex2Doffset(ReShade::BackBuffer, texcoord, int2(-1,  1)).rgb;
	float3 h = tex2Doffset(ReShade::BackBuffer, texcoord, int2( 0,  1)).rgb;
	float3 i = tex2Doffset(ReShade::BackBuffer, texcoord, int2( 1,  1)).rgb;

	// Soft min and max.
	float3 minRGB  = min(min(min(d, e), min(f, b)), h);
	float3 minRGB2 = min(min(min(minRGB, a), min(c, g)), i);
	minRGB += minRGB2;

	float3 maxRGB  = max(max(max(d, e), max(f, b)), h);
	float3 maxRGB2 = max(max(max(maxRGB, a), max(c, g)), i);
	maxRGB += maxRGB2;

	// Smooth minimum distance to 0 or 1 limits.
	float3 rcpMRGB = rcp(maxRGB);
	float3 ampRGB  = saturate(min(minRGB, 2.0 - maxRGB) * rcpMRGB);

	// Shaping amount of sharpening.
	ampRGB  = rsqrt(ampRGB);
	float peak = -3.0 * (1.0 - CAS_SHARPNESS) + 8.0;
	float3 wRGB = -rcp(ampRGB * peak);
	float3 rcpWeightRGB = rcp(4.0 * wRGB + 1.0);

	// Filter.
	float3 window = (b + d) + (f + h);
	float3 outColor = saturate((window * wRGB + e) * rcpWeightRGB);

	return outColor;
}

technique CAS
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = CASPass;
	}
}
