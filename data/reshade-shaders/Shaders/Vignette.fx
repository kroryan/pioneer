/**
 * Vignette effect
 * by Christian Cann Schuldt Jensen ~ CeeJay.dk
 *
 * Darkens the edges of the image to make it look more like it was shot with a camera lens.
 */

#include "ReShade.fxh"

uniform int VignetteType <
	ui_type = "combo";
	ui_label = "Vignette type";
	ui_items = "Round\0Diamond\0Square\0";
> = 0;

uniform float VignetteRatio <
	ui_type = "slider";
	ui_label = "Vignette Ratio";
	ui_tooltip = "Sets a width/height ratio for the vignette. 1.0 means circular.";
	ui_min = 0.15; ui_max = 6.0;
	ui_step = 0.001;
> = 1.0;

uniform float VignetteRadius <
	ui_type = "slider";
	ui_label = "Vignette Radius";
	ui_tooltip = "Controls the radius of the vignette.";
	ui_min = -1.0; ui_max = 3.0;
	ui_step = 0.001;
> = 2.0;

uniform float VignetteAmount <
	ui_type = "slider";
	ui_label = "Vignette Amount";
	ui_tooltip = "Controls the strength of the vignette effect.";
	ui_min = -1.0; ui_max = 1.0;
	ui_step = 0.001;
> = 0.5;

uniform int VignetteSlope <
	ui_type = "slider";
	ui_label = "Vignette Slope";
	ui_tooltip = "How far the vignette extends from the edges. Increase for a steeper edge.";
	ui_min = 2; ui_max = 16;
> = 2;

uniform float2 VignetteCenter <
	ui_type = "slider";
	ui_label = "Vignette Center";
	ui_tooltip = "Center point of the vignette.";
	ui_min = -1.0; ui_max = 1.0;
	ui_step = 0.001;
> = float2(0.0, 0.0);

float3 VignettePass(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;

	texcoord = texcoord - 0.5;

	if (VignetteType == 1)
		texcoord = abs(texcoord);
	if (VignetteType == 2)
		texcoord = pow(abs(texcoord), 4);

	texcoord -= float2(VignetteCenter.x, -VignetteCenter.y) * 0.5;
	texcoord *= float2(rcp(VignetteRatio), VignetteRatio);

	float vignette = clamp((1.0 - dot(texcoord, texcoord) * 4.0) * 0.25 + 0.75, 0.0, 1.0);
	vignette = pow(vignette, VignetteSlope);
	vignette = clamp(VignetteRadius - length(texcoord) * 2.0, 0.0, 1.0);
	vignette = pow(vignette, VignetteSlope);

	color = lerp(color, color * vignette, VignetteAmount);

	return color;
}

technique Vignette
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = VignettePass;
	}
}
