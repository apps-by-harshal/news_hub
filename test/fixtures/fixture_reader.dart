// Readers for the JSON fixtures in `test/fixtures/`.
//
// Paths are relative to the package root, which is the working directory
// `flutter test` runs in.

import 'dart:convert';
import 'dart:io';

/// Returns the raw contents of `test/fixtures/[name]`.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// Decodes `test/fixtures/[name]` as a JSON object.
///
/// Throws a [TypeError] if the fixture's top level is not a JSON object.
Map<String, Object?> fixtureJson(String name) =>
    jsonDecode(fixture(name)) as Map<String, Object?>;
