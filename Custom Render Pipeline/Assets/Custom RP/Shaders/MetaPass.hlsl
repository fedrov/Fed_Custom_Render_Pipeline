#ifndef CUSTOM_META_PASS_INCLUDED
#define CUSTOM_META_PASS_INCLUDED

#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"

struct Attributes 
{
	float3 positionOS : POSITION;
	float2 baseUV : TEXCOORD0;
	float2 lightMapUV : TEXCOORD1;
};

struct Varyings 
{
	float4 positionCS : SV_POSITION;
	float2 baseUV : VAR_BASE_UV;
};
//The meta pass can be used to generate different data. 
//What is requested is communicated via a bool4 unity_MetaFragmentControl flags vector.
bool4 unity_MetaFragmentControl;

float unity_OneOverOutputBoost;
float unity_MaxOutputValue;

Varyings MetaPassVertex (Attributes input) 
{
	Varyings output;
	input.positionOS.xy = input.lightMapUV * unity_LightmapST.xy + unity_LightmapST.zw;
	// minimum normalized positive floating point number
	// it seems that OpenGL doesn't work unless it explicitly uses the Z coordinate. 
	// We'll use the same dummy assignment that Unity's own meta pass uses
	input.positionOS.z = input.positionOS.z > 0.0 ? FLT_MIN : 0.0;
	output.positionCS = TransformWorldToHClip(input.positionOS);
	output.baseUV = TransformBaseUV(input.baseUV);
	return output;
}

float4 MetaPassFragment (Varyings input) : SV_TARGET 
{
	float4 base = GetBase(input.baseUV);
	Surface surface;
	ZERO_INITIALIZE(Surface, surface);
	surface.color = base.rgb;
	surface.metallic = GetMetallic(input.baseUV);
	surface.smoothness = GetSmoothness(input.baseUV);
	BRDF brdf = GetBRDF(surface);
	float4 meta = 0.0;
	//If the X flag is set then diffuse reflectivity is requested
	if (unity_MetaFragmentControl.x) 
	{
		meta = float4(brdf.diffuse, 1.0);
		//Unity's meta pass also boosts the results a bit, by adding half the specular reflectivity scaled by roughness
		//The idea behind this is that highly specular but rough materials also pass along some indirect light.
		meta.rgb += brdf.specular * brdf.roughness * 0.5;
		meta.rgb = min(PositivePow(meta.rgb, unity_OneOverOutputBoost), unity_MaxOutputValue);
	}
	else if (unity_MetaFragmentControl.y) 
	{
		meta = float4(GetEmission(input.baseUV), 1.0);
	}
	return meta;
}

#endif