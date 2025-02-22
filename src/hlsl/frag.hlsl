struct FSInput
{
    float4 inColor : TEXCOORD0;
};

float4 main(FSInput input) : SV_TARGET
{
    return input.inColor;
}