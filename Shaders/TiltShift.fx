/* 
Tilt-Shift PS v1.1.3 (c) 2018 Jacob Maximilian Fober, 
(based on TiltShift effect (c) 2016 kingeric1992)
Modified by Marot for ReShade 4.x compatibility.

This work is licensed under the Creative Commons 
Attribution-ShareAlike 4.0 International License. 
To view a copy of this license, visit 
http://creativecommons.org/licenses/by-sa/4.0/.
*/


	  ////////////
	 /// MENU ///
	////////////


uniform bool Line <
	ui_label = "Show Center Line";
> = false;

uniform int Axis <
	ui_label = "Angle";
	ui_type = "slider";
	ui_step = 1;
	ui_min = -89; ui_max = 90;
> = 0;

uniform float Offset <
	ui_type = "slider";
	ui_min = -1.41; ui_max = 1.41; ui_step = 0.01;
> = 0.05;

uniform float BlurCurve <
	ui_label = "Blur Curve";
	ui_type = "slider";
	ui_min = 1.0; ui_max = 5.0; ui_step = 0.01;
	ui_label = "Blur Curve";
> = 1.0;
uniform float BlurMultiplier <
	ui_label = "Blur Multiplier";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 100.0; ui_step = 0.2;
> = 6.0;

// First pass render target, to make sure Alpha channel exists
texture TiltShiftTarget { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler TiltShiftSampler { Texture = TiltShiftTarget; };


	  //////////////
	 /// SHADER ///
	//////////////

#include "ReShade.fxh"

void TiltShiftPass1PS(float4 vpos : SV_Position, float2 UvCoord : TEXCOORD, out float4 Image : SV_Target)
{
	const float Weight[11] =
	{
		0.082607,
		0.080977,
		0.076276,
		0.069041,
		0.060049,
		0.050187,
		0.040306,
		0.031105,
		0.023066,
		0.016436,
		0.011254
	};
		// Grab screen texture
		Image.rgb = tex2D(ReShade::BackBuffer, UvCoord).rgb;
		// Correct Aspect Ratio
		float2 UvCoordAspect = UvCoord;
		UvCoordAspect.y += ReShade::AspectRatio * 0.5 - 0.5;
		UvCoordAspect.y /= ReShade::AspectRatio;
		// Center coordinates
		UvCoordAspect = UvCoordAspect * 2.0 - 1.0;
		// Tilt vector
		float Angle = radians(-Axis);
		float2 TiltVector = float2(sin(Angle), cos(Angle));
		// Blur mask
		float BlurMask = abs(dot(TiltVector, UvCoordAspect) + Offset);
		BlurMask = saturate(saturate(BlurMask));
			// Set alpha channel
			Image.a = BlurMask;
		BlurMask = pow(Image.a, BlurCurve);
	// Horizontal gaussian blur 
	if(BlurMask > 0)
	{
		float UvOffset = ReShade::PixelSize.x * BlurMask * BlurMultiplier;
		Image.rgb *= Weight[0];
		[unroll]
		for (int i = 1; i < 11; i++)
		{
			float SampleOffset = i * UvOffset;
			Image.rgb += (
				tex2Dlod(ReShade::BackBuffer, float4(UvCoord.xy + float2(SampleOffset, 0.0), 0.0, 0.0)).rgb
				+ tex2Dlod(ReShade::BackBuffer, float4(UvCoord.xy - float2(SampleOffset, 0.0), 0.0, 0.0)).rgb
			) * Weight[i];
		}
	}
}

void TiltShiftPass2PS(float4 vpos : SV_Position, float2 UvCoord : TEXCOORD, out float4 Image : SV_Target)
{
	const float Weight[11] =
	{
		0.082607,
		0.080977,
		0.076276,
		0.069041,
		0.060049,
		0.050187,
		0.040306,
		0.031105,
		0.023066,
		0.016436,
		0.011254
	};
	// Grab second pass screen texture
	Image = tex2D(TiltShiftSampler, UvCoord);
	// Blur mask
	float BlurMask = pow(abs(Image.a), BlurCurve);
	// Vertical gaussian blur
	if(BlurMask > 0)
	{
		float UvOffset = ReShade::PixelSize.y * BlurMask * BlurMultiplier;
		Image.rgb *= Weight[0];
		[unroll]
		for (int i = 1; i < 11; i++)
		{
			float SampleOffset = i * UvOffset;
			Image.rgb += (
				tex2Dlod(TiltShiftSampler, float4(UvCoord.xy + float2(0.0, SampleOffset), 0.0, 0.0)).rgb
				+ tex2Dlod(TiltShiftSampler, float4(UvCoord.xy - float2(0.0, SampleOffset), 0.0, 0.0)).rgb
			) * Weight[i];
		}
	}
	// Draw red line
	// Image IS Red IF (Line IS True AND Image.a < 0.01), ELSE Image IS Image
	if (Line && Image.a < 0.01)
		Image.rgb = float3(1.0, 0.0, 0.0);
}


	  //////////////
	 /// OUTPUT ///
	//////////////

technique TiltShift < ui_label = "Tilt Shift"; >
{
	pass AlphaAndHorizontalGaussianBlur
	{
		VertexShader = PostProcessVS;
		PixelShader = TiltShiftPass1PS;
		RenderTarget = TiltShiftTarget;
	}
	pass VerticalGaussianBlurAndRedLine
	{
		VertexShader = PostProcessVS;
		PixelShader = TiltShiftPass2PS;
	}
}
