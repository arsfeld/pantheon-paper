# The Wingpanel indicator: GTK 3, granite and wingpanel, built the way
# nixos' packages/wingpanel-indicator-tailscale is.

# The model alone, for tests/test_indicator_model.vala: GLib and Gio only.
indicator_model_sources = files('Model.vala')

wingpanel_dep = dependency('wingpanel')

# Linked into the module; its generated constructor registers it on load.
indicator_resources = gnome.compile_resources(
    'paper-indicator-resources',
    'paper-indicator.gresource.xml',
    source_dir: meson.project_source_root() / 'data' / 'icons',
)

shared_module(
    'paper-indicator',
    common_sources + proxy_sources + indicator_model_sources + files(
        'ShortcutsView.vala',
        'Popover.vala',
        'Indicator.vala',
    ),
    indicator_resources,
    dependencies: core_deps + [
        dependency('gio-2.0'),
        dependency('gtk+-3.0'),
        dependency('granite'),
        wingpanel_dep,
    ],
    install: true,
    install_dir: wingpanel_dep.get_variable(
        pkgconfig: 'indicatorsdir',
        pkgconfig_define: ['libdir', get_option('prefix') / get_option('libdir')],
    ),
)
