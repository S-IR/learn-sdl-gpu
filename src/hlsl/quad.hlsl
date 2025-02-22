struct VSOutput
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float4 position : SV_Position;
};

#ifdef VERTEX_SHADER
cbuffer QuadProperties: register(b0,space1){
    float4x4 transform; 
}

cbuffer AtlasUBO: register(b1,space1){
    float2 tileSize; 
    float2 atlasIndex;   
}

struct VSInput
{
    float3 position : TEXCOORD0;
    float3 color : TEXCOORD1;
    float2 uv : TEXCOORD2;
};


VSOutput main(VSInput input)
{
    VSOutput output;
    output.color = float4(input.color,1);
    output.uv = input.uv * tileSize + atlasIndex * tileSize;;

    output.position = mul(float4(input.position, 1.0f), transform);
    return output;
}

#endif

#ifdef FRAGMENT_SHADER

Texture2D<float4> Texture : register(t0, space2);
SamplerState Sampler : register(s0, space2);

float4 main(VSOutput input) : SV_TARGET
{
    return Texture.Sample(Sampler, input.uv);
}
#endif