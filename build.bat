dxc src/hlsl/vert.hlsl -T vs_6_0 -Zi -E main -D VERTEX_SHADER -spirv -Fo  resources/shader-binaries/shader.vert.spv
dxc src/hlsl/frag.hlsl -T ps_6_0 -Zi -E main -D FRAGMENT_SHADER -spirv -Fo resources/shader-binaries/shader.frag.spv
