struct VSInput
{
    float3 position : TEXCOORD0;
};

struct VSOutput
{
    float4 position : SV_POSITION;
    float4 outColor : TEXCOORD0;
};

VSOutput main(VSInput input)
{
    VSOutput output;
    output.outColor = float4(1,1,1,1);
    output.position = float4(input.position, 1.0f);
    return output;
}