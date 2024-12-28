blueprints = custom_target('blueprints',
  input: files(
    'MainWindow.blp',
    'Application.blp',
  ),
  output: '.',
  command: [find_program('blueprint-compiler'), 'batch-compile', '@OUTDIR@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
)
