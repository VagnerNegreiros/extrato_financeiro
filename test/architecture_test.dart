import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the dependency rule: domain code is plain Dart and depends only
/// on other domain code and the framework-free parts of `core`.
void main() {
  const allowedPackages = {
    'package:collection/',
    'package:decimal/',
    'package:freezed_annotation/',
    'package:meta/',
  };
  const allowedCore = {
    'package:extrato_financeiro/core/async/',
    'package:extrato_financeiro/core/money/',
    'package:extrato_financeiro/core/result/',
    'package:extrato_financeiro/core/time/',
  };

  final importPattern = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  List<File> dartFilesUnder(String path) =>
      Directory(path)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('.freezed.dart'))
          .where((file) => !file.path.endsWith('.g.dart'))
          .toList();

  bool isDomainImport(String uri) =>
      uri.startsWith('package:extrato_financeiro/features/') &&
      uri.contains('/domain/');

  bool isAllowed(String uri) =>
      uri.startsWith('dart:') && uri != 'dart:io' && uri != 'dart:ui' ||
      allowedPackages.any(uri.startsWith) ||
      allowedCore.any(uri.startsWith) ||
      isDomainImport(uri);

  test('domain layer depends on nothing outside domain and pure core', () {
    final domainFiles = dartFilesUnder('lib/features')
        .where((file) => file.path.replaceAll(r'\', '/').contains('/domain/'))
        .toList();
    expect(domainFiles, isNotEmpty);

    final violations = <String>[];
    for (final file in domainFiles) {
      for (final match in importPattern.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        // Relative imports would stay inside the same folder tree.
        if (!uri.contains(':')) continue;
        if (!isAllowed(uri)) violations.add('${file.path} -> $uri');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('pure core does not depend on Flutter', () {
    final violations = <String>[];
    for (final folder in ['async', 'money', 'result', 'time']) {
      for (final file in dartFilesUnder('lib/core/$folder')) {
        for (final match in importPattern.allMatches(file.readAsStringSync())) {
          final uri = match.group(1)!;
          if (uri.startsWith('package:flutter')) {
            violations.add('${file.path} -> $uri');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
