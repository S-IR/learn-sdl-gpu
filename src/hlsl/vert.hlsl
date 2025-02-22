struct VSInput
{
    float3 position : TEXCOORD0;
    float3 color : TEXCOORD1;
    float2 uv : TEXCOORD2;
};

struct VSOutput
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float4 position : SV_Position;
};

VSOutput main(VSInput input)
{
    VSOutput output;
    output.color = float4(input.color,1);
    output.uv = input.uv;

    output.position = float4(input.position, 1.0f);
    return output;
}