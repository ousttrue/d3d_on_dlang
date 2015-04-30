struct VS_INPUT
{
    float4 Position   : POSITION;
    float4 Color      : COLOR;
};

struct VS_OUTPUT
{
    float4 Position   : SV_POSITION;
    float4 Color      : COLOR;
};

cbuffer c0
{
	float4x4 ModelMatrix;
};

VS_OUTPUT VS( VS_INPUT In )
{
    VS_OUTPUT Output;
	//Output.Position = mul(In.Position, ModelMatrix);
	Output.Position = In.Position;
    Output.Color    = In.Color;
    return Output;    
}

float4 PS( VS_OUTPUT In ) : SV_TARGET
{
    return In.Color;
}

technique11 T0
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_5_0, VS()));
		SetGeometryShader(NULL);
		SetHullShader(NULL);
		SetDomainShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, PS()));
		SetComputeShader(NULL);
	}
} 
