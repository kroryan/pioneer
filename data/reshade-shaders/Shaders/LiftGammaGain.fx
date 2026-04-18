/**
 * Lift Gamma Gain
 * by 3an and CeeJay.dk
 *
 * Allows color correction via lift, gamma, and gain controls.
 */

#include "ReShade.fxh"

uniform float3 RGBLift <
	ui_type = "color";
	ui_label = "RGB Lift";
	ui_tooltip = "Adjusts shadows (lift).";
	ui_min = 0.000; ui_max = 1.000;
	ui_step = 0.001;
> = float3(1.000, 1.000, 1.000);

uniform float3 RGBGamma <
	ui_type = "color";
	ui_label = "RGB Gamma";
	ui_tooltip = "Adjusts midtones (gamma).";
	ui_min = 0.000; ui_max = 1.000;
	ui_step = 0.001;
> = float3(1.000, 1.000, 1.000);

uniform float3 RGBGain <
	ui_type = "color";
	ui_label = "RGB Gain";
	ui_tooltip = "Adjusts highlights (gain).";
	ui_min = 0.000; ui_max = 2.000;
	ui_step = 0.001;
> = float3(1.000, 1.000, 1.000);

float3 LiftGammaGainPass(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;

	// Lift
	color = color * (1.5 - 0.5 * RGBLift) + 0.5 * RGBLift - 0.5;
	color = saturate(color);

	// Gamma
	color = pow(color, 1.0 / RGBGamma);

	// Gain
	color *= RGBGain;

	return saturate(color);
}

technique LiftGammaGain
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = LiftGammaGainPass;
	}
}
