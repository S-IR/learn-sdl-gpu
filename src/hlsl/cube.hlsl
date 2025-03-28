


struct VSOutput
{
    float2 uv : TEXCOORD0;
    float4 position : SV_Position;
};

#ifdef VERTEX

struct CubeData
{
    float3 worldPosition;
    float atlasIndex; 
};
StructuredBuffer<CubeData> CubesSBO : register(t0, space0);

cbuffer CameraUBO : register(b0, space1)
{
  matrix view;
  matrix proj;
};


cbuffer AtlasUBO: register(b1,space1){
    float2 atlasTiles; 
    float2 atlasTileSize; 
}

struct VSInput
{
    float3 position : TEXCOORD0;
    float2 uv : TEXCOORD1;
    uint instanceId : SV_InstanceID;

};


VSOutput main(VSInput input)
{


    VSOutput output;
    CubeData cube = CubesSBO[input.instanceId];

     // Compute the tile coordinates in the atlas
    float tileX = fmod(cube.atlasIndex, atlasTiles.x);
    float tileY = floor(cube.atlasIndex / atlasTiles.x);

    // Normalize to UV space
    float2 baseUV = float2(tileX, tileY) * atlasTileSize;

    output.uv = baseUV + input.uv * atlasTileSize;

    float4 worldPos= float4(input.position + cube.worldPosition, 1);
    float4 viewPos = mul(view, worldPos);
    float4 clipPos = mul(proj, viewPos);
    output.position = clipPos;

    return output;
}
#endif

#ifdef FRAGMENT

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
     if (input.uv.x < 0.0 || input.uv.y < 0.0 ) {
        discard;
    }
    output.color = Texture.Sample(Sampler,input.uv);
    output.depth = input.position.z;
    return output;
}

#endif