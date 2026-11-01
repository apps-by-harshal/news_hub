import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:news_hub/core/storage/local_database.dart';
import 'package:news_hub/core/storage/local_database_impl.dart';

void main() {
  late Directory tempDir;
  late List<String> calls;

  /// A [LocalDatabaseImpl] over the real [Hive], set up in [tempDir].
  ///
  /// By default `initialize` records the call and runs
  /// `Hive.init(tempDir.path)`; pass [initialize] to replace it. Adapter
  /// registration is only recorded, because `Box<String>` needs no adapter.
  LocalDatabase buildDatabase({Future<void> Function()? initialize}) =>
      LocalDatabaseImpl(
        hive: Hive,
        initialize:
            initialize ??
            () async {
              calls.add('initialize');
              Hive.init(tempDir.path);
            },
        registerAdapters: () => calls.add('registerAdapters'),
      );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('news_hub_local_db_');
    calls = <String>[];
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('init', () {
    test('initialises Hive, then registers the adapters', () async {
      await buildDatabase().init();

      expect(calls, <String>['initialize', 'registerAdapters']);
    });

    test('does nothing when called a second time', () async {
      final LocalDatabase database = buildDatabase();

      await database.init();
      await database.init();

      expect(calls, <String>['initialize', 'registerAdapters']);
    });

    test('runs once when called concurrently', () async {
      final LocalDatabase database = buildDatabase();

      await Future.wait(<Future<void>>[database.init(), database.init()]);

      expect(calls, <String>['initialize', 'registerAdapters']);
    });

    test('passes a failure on, registers no adapters, and retries on the '
        'next call', () async {
      int attempts = 0;
      final LocalDatabase database = buildDatabase(
        initialize: () async {
          attempts++;
          calls.add('initialize');
          if (attempts == 1) {
            throw const FileSystemException('no disk');
          }
          Hive.init(tempDir.path);
        },
      );

      await expectLater(database.init(), throwsA(isA<FileSystemException>()));
      expect(calls, <String>['initialize']);

      await database.init();
      expect(calls, <String>['initialize', 'initialize', 'registerAdapters']);
    });
  });

  group('openBox', () {
    test('throws a StateError before init', () async {
      await expectLater(
        buildDatabase().openBox<String>('notes'),
        throwsStateError,
      );
    });

    test('throws a StateError while init is still running', () async {
      final Completer<void> gate = Completer<void>();
      final LocalDatabase database = buildDatabase(
        initialize: () async {
          await gate.future;
          Hive.init(tempDir.path);
        },
      );

      final Future<void> initializing = database.init();
      await expectLater(database.openBox<String>('notes'), throwsStateError);

      gate.complete();
      await initializing;
      expect((await database.openBox<String>('notes')).isOpen, isTrue);
    });

    test('opens the box after init and returns the same open box', () async {
      final LocalDatabase database = buildDatabase();
      await database.init();

      final Box<String> box = await database.openBox<String>('notes');
      final Box<String> again = await database.openBox<String>('notes');

      expect(box.isOpen, isTrue);
      expect(box.name, 'notes');
      expect(again, same(box));
    });
  });

  group('close', () {
    test('closes the open boxes; openBox opens them again without a second '
        'init', () async {
      final LocalDatabase database = buildDatabase();
      await database.init();
      final Box<String> box = await database.openBox<String>('notes');
      await box.put('key', 'value');

      await database.close();
      expect(box.isOpen, isFalse);

      final Box<String> reopened = await database.openBox<String>('notes');
      expect(reopened.isOpen, isTrue);
      expect(reopened.get('key'), 'value');
      expect(calls, <String>['initialize', 'registerAdapters']);
    });
  });
}
