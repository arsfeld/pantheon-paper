# Each unit test is the core compiled with one test file.
foreach name : ['strip', 'common', 'layout', 'tiling', 'drop', 'drag', 'focus', 'ring']
    test(name, executable('test-' + name, core_sources + files('test_' + name + '.vala'), dependencies: core_deps))
endforeach

# Both schemas compile strictly (types, defaults, ranges).
compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
    test('schemas', compile_schemas, args: ['--strict', '--dry-run', meson.project_source_root() / 'data'])
endif

# The indicator's and the plug's models run against GSettings' memory backend,
# reading the schemas compiled into this build directory.
if is_variable('indicator_model_sources') or is_variable('plug_model_sources')
    test_schemas = custom_target(
        'test-schemas',
        input: files(
            '../data/io.github.arsfeld.paper.gschema.xml',
            '../data/io.github.arsfeld.paper.keybindings.gschema.xml',
        ),
        output: 'gschemas.compiled',
        command: [find_program('glib-compile-schemas'), '--strict', '--targetdir', '@OUTDIR@', meson.project_source_root() / 'data'],
    )
endif

# The indicator's model, with a fake proxy.
if is_variable('indicator_model_sources')
    test('indicator-model', executable(
            'test-indicator-model',
            common_sources + proxy_sources + indicator_model_sources + files('test_indicator_model.vala'),
            dependencies: core_deps + [dependency('gio-2.0')],
        ),
        depends: test_schemas,
        env: ['GSETTINGS_BACKEND=memory', 'GSETTINGS_SCHEMA_DIR=' + meson.current_build_dir()],
    )
endif

# The plug's models (rules, presets, key owners), plus a test schema layered
# over the plugin's for the key-owner scan.
if is_variable('plug_model_sources')
    subdir('schemas')
    test('plug-models', executable(
            'test-plug-models',
            common_sources + plug_model_sources + files('test_plug_models.vala'),
            dependencies: core_deps + [dependency('gio-2.0')],
        ),
        depends: [test_schemas, plug_test_schemas],
        env: [
            'GSETTINGS_BACKEND=memory',
            'GSETTINGS_SCHEMA_DIR=' + meson.current_build_dir(),
            'PAPER_TEST_SCHEMA_DIR=' + plug_test_schema_dir,
        ],
    )
endif
