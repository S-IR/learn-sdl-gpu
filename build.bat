dxc src/hlsl/vert.hlsl -T vs_6_0 -Zi -E main -spirv -Fo  resources/shader-binaries/shader.vert.spv
dxc src/hlsl/frag.hlsl -T ps_6_0 -Zi -E main -spirv -Fo resources/shader-binaries/shader.frag.spv

@REM DXIL creating
dxc src/hlsl/vert.hlsl -T vs_6_0 -Zi -E main -Qembed_debug -Fo  resources/shader-binaries/shader.vert.dxil
dxc src/hlsl/frag.hlsl -T ps_6_0 -Zi -E main -Qembed_debug -Fo resources/shader-binaries/shader.frag.dxil
