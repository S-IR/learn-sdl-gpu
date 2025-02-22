struct VSInput
{
    float3 position : TEXCOORD0;
    float3 color : TEXCOORD1;

};

struct VSOutput
{
    float4 color : TEXCOORD0;
    float4 position : SV_POSITION;
};

VSOutput main(VSInput input)
{
    VSOutput output;
    output.color = float4(input.color,1);
    output.position = float4(input.position, 1.0f);
    return output;
}