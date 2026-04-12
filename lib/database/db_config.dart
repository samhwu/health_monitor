// lib/database/db_config.dart
export 'db_setup_web.dart' if (dart.library.io) 'db_setup_native.dart';
