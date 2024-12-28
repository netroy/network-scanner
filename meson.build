project('network-scanner', 'vala', 'c')

gnome = import('gnome')
i18n = import('i18n')
blueprint_compiler = find_program('blueprint-compiler')

add_project_arguments(
  '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
  language: 'c'
)

dependencies = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gtk4'),
  dependency('libadwaita-1'),
  dependency('json-glib-1.0'),
  dependency('gio-2.0')
]

# Compile blueprint files
blueprints = custom_target('blueprints',
  input: files(
    'src/MainWindow.blp'
  ),
  output: '.',
  command: [
    blueprint_compiler,
    'batch-compile',
    '@OUTDIR@/ui',
    '@CURRENT_SOURCE_DIR@/src',
    '@INPUT@'
  ]
)

# Generate resources
gresources = gnome.compile_resources(
  'gresources',
  'data/gresource.xml',
  dependencies: blueprints,
  source_dir: meson.current_build_dir()
)

# Translations
i18n.gettext(meson.project_name(),
  preset: 'glib',
  args: [
    '--keyword=_',
    '--from-code=UTF-8'
  ]
)

# Configure
conf = configuration_data()
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
conf.set_quoted('PACKAGE_VERSION', meson.project_version())

config_h = configure_file(
  output: 'config.h',
  configuration: conf
)

config_dep = declare_dependency(
  dependencies: [
    meson.get_compiler('vala').find_library('config', dirs: meson.current_source_dir()),
  ]
)

executable(
  meson.project_name(),
  'src/Application.vala',
  'src/MainWindow.vala',
  'src/NetworkScanner.vala',
  'src/NetworkDevice.vala',
  config_h,
  gresources,
  dependencies: [dependencies, config_dep],
  install: true
)
