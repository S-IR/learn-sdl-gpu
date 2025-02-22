


struct VSOutput
{
    float3 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float4 position : SV_Position;
};

#ifdef VERTEX_SHADER


StructuredBuffer<CubeData> CubesBuffer : register(t0, space0);

cbuffer CameraUBO : register(b0, space1)
{
  matrix view;
  matrix proj;
};


cbuffer AtlasUBO: register(b1,space1){
    float2 atlasTileSize; 
    float2 atlasIndex; 
}

struct VSInput
{
    float3 position : TEXCOORD0;
    float3 color: TEXCOORD1;
    float2 uv : TEXCOORD2;
    uint instanceId : SV_InstanceID;

};


VSOutput main(VSInput input)
{
    VSOutput output;
    output.color = input.color;
    output.uv = input.uv * atlasTileSize + atlasIndex * atlasTileSize;

    float4 worldPos= float4(input.position, 1);
    float4 viewPos = mul(view, worldPos);
    float4 clipPos = mul(proj, viewPos);

    output.position = clipPos;

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

#define NearPlane 0.01
#define FarPlane 60
FSOutput main(VSOutput input) 
{   
    FSOutput output;
    output.color = float4(input.color,1.0);
    output.depth = input.position.z;
    return output;
}

#endif