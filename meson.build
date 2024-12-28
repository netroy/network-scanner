project('network-scanner', 'vala', 'c',
    version: '0.1.0',
    default_options: [
        'warning_level=2',
    ]
)

# Dependencies
gtk_dep = dependency('gtk4')
glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
gio_dep = dependency('gio-2.0')

# Source files
sources = files(
    'src/Application.vala',
    'src/MainWindow.vala'
)

# Executable
executable(
    'network-scanner',
    sources,
    dependencies: [
        gtk_dep,
        glib_dep,
        gobject_dep,
        gio_dep
    ],
    install: true
)