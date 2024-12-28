project('network-scanner', 'vala', 'c',
  version: '0.1.0',
  meson_version: '>= 0.56.0'
)

i18n = import('i18n')
gnome = import('gnome')

add_project_arguments(
  '--target-glib=2.50',
  language: 'vala'
)

add_project_arguments(
  '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
  language: 'c'
)

# Dependencies
gtk_dep = dependency('gtk4')
adw_dep = dependency('libadwaita-1', version: '>= 1.4')
glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
gio_dep = dependency('gio-2.0')
json_glib_dep = dependency('json-glib-1.0')

# Configure config.h
conf = configuration_data()
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))

config_h = configure_file(
  output: 'config.h',
  configuration: conf
)

config_h_dir = include_directories('.')
config_dep = meson.get_compiler('vala').find_library('config', dirs: meson.current_source_dir())

# Source files
sources = files(
  'src/Application.vala',
  'src/MainWindow.vala',
  'src/NetworkScanner.vala',
  'src/NetworkDevice.vala'
)

executable(
  'network-scanner',
  sources,
  config_h,
  dependencies: [
    gtk_dep,
    adw_dep,
    glib_dep,
    gobject_dep,
    gio_dep,
    json_glib_dep,
    config_dep
  ],
  include_directories: config_h_dir,
  install: true
)

subdir('data')
subdir('po')
