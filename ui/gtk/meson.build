project('pcb-inspector-gtk', 'vala', 'c',
  version: '1.0.0',
  license: 'MIT',
  default_options: [
    'warning_level=2',
    'optimization=2',
  ])

deps = [
  dependency('gtk4', version: '>=4.6'),
  dependency('gdk-pixbuf-2.0', version: '>=2.40'),
  dependency('json-glib-1.0', version: '>=1.6'),
]

sources = files(
  'src/main.vala',
  'src/app.vala',
  'src/window.vala',
  'src/config.vala',
  'src/models/defect_info.vala',
  'src/models/detection_record.vala',
  'src/services/storage_service.vala',
  'src/services/pipeline_service.vala',
  'src/services/hardware_service.vala',
  'src/services/detector_runner.vala',
  'src/widgets/defect_list.vala',
  'src/widgets/image_viewer.vala',
  'src/widgets/history_panel.vala',
)

executable('pcb-inspector-gtk', sources,
  dependencies: deps,
  vala_args: ['--pkg', 'posix'],
  install: true,
)
