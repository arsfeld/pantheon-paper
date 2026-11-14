project('pantheon-paper', 'vala', 'c', version: '0.1.0', meson_version: '>= 0.60')

# PaperWM-style scrolling tiling for Pantheon, as a Gala plugin.
#
# src/core/ is pure code (no Mutter types): the strip model, the layout, the
# tiling predicate and drop hit-testing. It is compiled into the plugin and
# into each unit test. src/*.vala binds it to Mutter and Gala.

add_project_arguments('-DG_LOG_DOMAIN="pantheon-paper"', language: 'c')
add_project_arguments('--vapidir', meson.current_source_dir() / 'vapi', language: 'vala')

gnome = import('gnome')

core_deps = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gee-0.8'),
    meson.get_compiler('c').find_library('m'),
]
# src/common/ is GLib/GObject/Gee only (no Gio, no Mutter), shared by the
# plugin, the unit tests and the Wingpanel indicator and Switchboard plug.
subdir('src/common')
core_sources = common_sources
subdir('src/core')

# The plugin must be built against the mutter gala itself uses. mutter does
# not install Vala bindings; vapi/ carries the ones from gala's source tree
# (tag 8.6.2), as arsfeld/pantheon-global-menu does: Mutter 46 (libmutter-14,
# elementary OS 8's gala) and Mutter 48 (libmutter-16, NixOS's gala).
#   [API version, mutter release, vala defines gala's vapis guard on]
supported_mutters = [
    ['14', '46', []],
    ['16', '48', ['HAS_MUTTER47', 'HAS_MUTTER48']],
]
mutter_deps = []
mutter_vala_args = []
foreach m : supported_mutters
    api = m[0]
    release = m[1].to_int()
    probe = dependency(
        'libmutter-' + api,
        version: ['>= @0@'.format(release), '< @0@'.format(release + 1)],
        required: false,
    )
    if probe.found()
        mutter_deps = [
            probe,
            dependency('mutter-clutter-' + api),
            dependency('mutter-cogl-' + api),
            dependency('mutter-mtk-' + api),
        ]
        foreach define : m[2]
            mutter_vala_args += ['--define', define]
        endforeach
    endif
endforeach

if mutter_deps.length() > 0
    plugin_sources = files()
    subdir('src')
    shared_module(
        'gala-paper',
        core_sources + plugin_sources,
        dependencies: core_deps + mutter_deps + [
            dependency('gala'),
            dependency('gio-2.0'),
            dependency('gio-unix-2.0'),
            dependency('gdk-pixbuf-2.0'),
            dependency('pango'),
            dependency('cairo-gobject'),
        ],
        vala_args: mutter_vala_args,
        install_rpath: mutter_deps[0].get_variable(pkgconfig: 'typelibdir'),
        install: true,
        install_dir: get_option('prefix') / get_option('libdir') / 'gala' / 'plugins',
    )
else
    error('No supported mutter found: need mutter 46 (libmutter-14) or 48 (libmutter-16).')
endif

install_data(
    'data/io.github.arsfeld.paper.keybindings.gschema.xml',
    'data/io.github.arsfeld.paper.gschema.xml',
    install_dir: get_option('datadir') / 'glib-2.0' / 'schemas',
)
gnome.post_install(glib_compile_schemas: true)

subdir('tests')
