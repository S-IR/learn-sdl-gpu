struct FSInput
{
    float4 color : TEXCOORD0;
};

float4 main(FSInput input) : SV_TARGET
{
    return input.color;
}