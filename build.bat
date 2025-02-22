dxc src/hlsl/cube.hlsl -T vs_6_0 -Zi -E main -DVERTEX_SHADER -spirv -Fo  resources/shader-binaries/shader.vert.spv
dxc src/hlsl/cube.hlsl -T ps_6_0 -Zi -E main -DFRAGMENT_SHADER -spirv -Fo resources/shader-binaries/shader.frag.spv

@REM DXIL creating
 dxc src/hlsl/vert.hlsl -T vs_6_0 -Zi -E main -DVERTEX_SHADER -Qembed_debug -Fo  resources/shader-binaries/shader.vert.dxil
 dxc src/hlsl/frag.hlsl -T ps_6_0 -Zi -E main -DFRAGMENT_SHADER -Qembed_debug -Fo resources/shader-binaries/shader.frag.dxil
