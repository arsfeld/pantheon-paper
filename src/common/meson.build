common_sources = files(
    'AppEntry.vala',
    'Presets.vala',
    'Rules.vala',
    'Accels.vala',
)
# The D-Bus client interface needs gio, so it is kept out of common_sources
# (compiled into the plugin) and built only into the indicator, the plug and
# their tests.
proxy_sources = files('PaperProxy.vala')
