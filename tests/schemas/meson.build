# The test schema for /plug/key_owners, compiled on its own so the test can
# layer it over the plugin's schemas with SettingsSchemaSource.from_directory.
plug_test_schemas = custom_target(
    'plug-test-schemas',
    input: files('io.github.arsfeld.paper.test.gschema.xml'),
    output: 'gschemas.compiled',
    command: [find_program('glib-compile-schemas'), '--strict', '--targetdir', '@OUTDIR@', meson.current_source_dir()],
)
plug_test_schema_dir = meson.current_build_dir()
