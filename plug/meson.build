# The Switchboard plug: GTK 4, granite-7 and switchboard-3.

# The models alone, for tests/test_plug_models.vala: GLib and Gio only.
plug_model_sources = files('RulesModel.vala', 'PresetsModel.vala', 'KeyOwners.vala')

switchboard_dep = dependency('switchboard-3')

shared_module(
    'paper-plug',
    common_sources + proxy_sources + plug_model_sources + files(
        'LayoutPage.vala',
        'RulesPage.vala',
        'ShortcutsPage.vala',
        'Plug.vala',
    ),
    dependencies: core_deps + [
        dependency('gio-2.0'),
        dependency('gio-unix-2.0'),
        dependency('gtk4'),
        dependency('granite-7'),
        dependency('libadwaita-1'),
        switchboard_dep,
    ],
    install: true,
    install_dir: switchboard_dep.get_variable(
        pkgconfig: 'plugsdir',
        pkgconfig_define: ['libdir', get_option('prefix') / get_option('libdir')],
    ) / 'personal',
)
