// Coverage gate for the layers the challenge requires (domain and view
// models). Reads coverage/lcov.info produced by `flutter test --coverage`,
// prints a per-file report, writes coverage/lcov_gate.info (for genhtml)
// and exits with code 1 when the total is below the threshold.
//
// Usage: dart run tool/coverage.dart [--min=70]
// ignore_for_file: avoid_print

import 'dart:io';

const _defaultMinimum = 70.0;

bool _isGated(String path) {
  final normalized = path.replaceAll(r'\', '/');
  if (normalized.endsWith('.g.dart') || normalized.endsWith('.freezed.dart')) {
    return false;
  }
  return normalized.contains('/domain/') ||
      normalized.endsWith('_view_model.dart');
}

void main(List<String> args) {
  final minimum =
      args
          .where((arg) => arg.startsWith('--min='))
          .map((arg) => double.tryParse(arg.substring(6)))
          .firstOrNull ??
      _defaultMinimum;

  final input = File('coverage/lcov.info');
  if (!input.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info not found. Run flutter test --coverage.',
    );
    exit(2);
  }

  final records = <List<String>>[];
  var current = <String>[];
  for (final line in input.readAsLinesSync()) {
    current.add(line);
    if (line == 'end_of_record') {
      records.add(current);
      current = [];
    }
  }

  var found = 0;
  var hit = 0;
  final gated = <String>[];
  final rows = <(String, int, int)>[];
  for (final record in records) {
    final file = record.first.startsWith('SF:')
        ? record.first.substring(3)
        : '';
    if (!_isGated(file)) continue;
    final lines = record.where((line) => line.startsWith('DA:'));
    final total = lines.length;
    final covered = lines.where((line) => !line.endsWith(',0')).length;
    found += total;
    hit += covered;
    rows.add((file.replaceAll(r'\', '/'), covered, total));
    gated.addAll(record);
  }

  rows.sort((a, b) => a.$1.compareTo(b.$1));
  for (final (file, covered, total) in rows) {
    final percent = total == 0 ? 100 : covered * 100 / total;
    print('${percent.toStringAsFixed(1).padLeft(6)}%  $covered/$total  $file');
  }

  File('coverage/lcov_gate.info').writeAsStringSync('${gated.join('\n')}\n');
  final percent = found == 0 ? 0.0 : hit * 100 / found;
  print(
    '\nDomain + view models: ${percent.toStringAsFixed(2)}% '
    '($hit/$found lines), minimum ${minimum.toStringAsFixed(0)}%',
  );
  if (percent < minimum) {
    stderr.writeln('Coverage below the minimum.');
    exit(1);
  }
}
