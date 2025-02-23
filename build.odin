package build
import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "core:unicode/utf8"

ShaderType :: enum {
	Nil,
	Vertex,
	Fragment,
}

SHADERS :: [?]string{"cube.hlsl"}

inputDir := filepath.join({"src", "hlsl"})
outputDir := filepath.join({"resources", "shader-binaries"})

SPIRV :: true
DXIL :: true

PRINT_COMMAND :: true

main :: proc() {
	defer free_all(context.allocator)


	for shader in SHADERS {
		ensure(strings.has_suffix(shader, ".hlsl"), "only hlsl files allowed")

		path := filepath.join({inputDir, shader})
		outDir := filepath.dir(filepath.join({outputDir, shader}))
		os.make_directory(outDir)


		if SPIRV {
			compile_shader(path, outDir, "spv", .vertex)
			compile_shader(path, outDir, "spv", .fragment)
		}

		if DXIL {
			compile_shader(path, outDir, "dxil", .vertex)
			compile_shader(path, outDir, "dxil", .fragment)
		}

	}


}
compile_shader :: proc(path, dir, ext: string, stage: enum {
		vertex,
		fragment,
	}) {
	name := strings.trim_suffix(filepath.base(path), ".hlsl")
	stage := stage == .vertex ? "vertex" : "fragment"
	define := strings.to_upper(stage)

	exec(
		{
			"shadercross",
			"-g",
			"--stage",
			string(stage),
			"--output",
			filepath.join({dir, strings.join({name, stage, ext}, ".")}),
			fmt.tprintf("-D%s", define),
			path,
		},
	)
}


exec :: proc(command: []string) {
	if PRINT_COMMAND {
		fmt.printfln(strings.join(command, " "))

	}
	state, stdOut, stdErr, error := os2.process_exec(
		os2.Process_Desc{working_dir = ".", command = command},
		allocator = context.temp_allocator,
	)

	if state.exit_code != 0 {
		msg := fmt.tprintf("%s%s", string(stdOut), string(stdErr))
		panic(msg)
	}
}
