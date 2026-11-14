# Each unit test is the core compiled with one test file.
foreach name : ['strip', 'common', 'layout', 'tiling', 'drop', 'drag']
    test(name, executable('test-' + name, core_sources + files('test_' + name + '.vala'), dependencies: core_deps))
endforeach

# Both schemas compile strictly (types, defaults, ranges).
compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
    test('schemas', compile_schemas, args: ['--strict', '--dry-run', meson.project_source_root() / 'data'])
endif
