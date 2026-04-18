/**
 * Technicolor 2
 * by Prod80
 *
 * A more modern variant of the Technicolor shader that simulates
 * the look of the old Technicolor film process.
 */

#include "ReShade.fxh"

uniform float4 ColorStrength <
	ui_type = "color";
	ui_label = "Color Strength";
	ui_tooltip = "Higher means more pronounced technicolor effect.\nMust be greater than 0.";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.01;
> = float4(0.2, 0.2, 0.2, 0.2);

uniform float Brightness <
	ui_type = "slider";
	ui_label = "Brightness";
	ui_min = 0.5; ui_max = 1.5;
	ui_step = 0.01;
> = 1.0;

uniform float Saturation <
	ui_type = "slider";
	ui_label = "Saturation";
	ui_tooltip = "Additional saturation control since technicolor tends to oversaturate the image.";
	ui_min = 0.0; ui_max = 1.5;
	ui_step = 0.01;
> = 0.85;

uniform float Strength <
	ui_type = "slider";
	ui_label = "Strength";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.01;
> = 1.0;

float3 Technicolor2Pass(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;

	float3 temp = 1.0 - color;
	float3 target  = temp.grg;
	float3 target2 = temp.bbr;
	float3 temp2   = color * target;
	temp2 *= target2;

	float4 cs = ColorStrength;
	temp = temp2 * float3(cs.r, cs.g, cs.b);
	temp2 *= cs.a;

	float3 result = temp + color;
	result = lerp(result, color + temp2, 0.5);

	// Saturation
	float luma = dot(result, float3(0.2126, 0.7152, 0.0722));
	result = lerp(luma.xxx, result, Saturation);

	// Brightness
	result *= Brightness;

	return saturate(lerp(color, result, Strength));
}

technique Technicolor2
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = Technicolor2Pass;
	}
}
