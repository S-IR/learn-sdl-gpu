struct VSInput
{
    float3 inPosition : POSITION;
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
    output.position = float4(input.inPosition, 1.0f);
    return output;
}