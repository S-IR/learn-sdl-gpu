


struct VSOutput
{
    float2 uv : TEXCOORD1;
    float4 position : SV_Position;
};

#ifdef VERTEX_SHADER


cbuffer CubeUBO: register(b0,space1){
    float4x4 transform; 
}
cbuffer AtlasUBO: register(b1,space1){
    float2 atlasTileSize; 
    float2 atlasIndex; 
}

struct VSInput
{
    float3 position : TEXCOORD0;
    float2 uv : TEXCOORD2;
    uint instanceId : SV_InstanceID;

};


VSOutput main(VSInput input)
{
    VSOutput output;

    output.uv = input.uv * atlasTileSize + atlasIndex * atlasTileSize;
    output.position = mul(float4(input.position,1.0),transform);

    return output;
}
#endif

#ifdef FRAGMENT_SHADER

Texture2D<float4> Texture : register(t0, space2);
SamplerState Sampler : register(s0, space2);
struct FSOutput
{
  float4 color : SV_Target;
  float depth : SV_Depth;
};
FSOutput main(VSOutput input) 
{   
    FSOutput output;
    output.color = Texture.Sample(Sampler, input.uv);
    output.depth = 0.2;
    return output;
}

#endif