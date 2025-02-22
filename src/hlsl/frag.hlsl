struct FSInput
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
};
Texture2D<float4> Texture : register(t0, space2);
SamplerState Sampler : register(s0, space2);

float4 main(FSInput input) : SV_TARGET
{
    return Texture.Sample(Sampler, input.uv);
}