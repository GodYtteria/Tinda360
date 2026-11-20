import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/services/store_sounds.dart';

import '../support/recording_app_log.dart';

final class _RecordingSoundOutput implements StoreSoundOutput {
  new({this.failure});

  final Exception? failure;
  final List<StoreSound> played = [];

  @override
  Future<void> play(StoreSound sound) async {
    final error = failure;
    if (error != null) throw error;
    played.add(sound);
  }
}

final class _MemorySettingStore implements StoreSoundSettingStore {
  new(this.enabled);

  bool enabled;

  @override
  Future<bool> read() async => enabled;

  @override
  Future<void> write({required bool enabled}) async => this.enabled = enabled;
}

void main() {
  late Directory scratch;
  late RecordingAppLog log;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('store_sounds_test');
    log = RecordingAppLog();
  });

  tearDown(() => scratch.delete(recursive: true));

  ProviderContainer containerWith(
    StoreSoundOutput output,
    StoreSoundSettingStore store,
  ) {
    final container = ProviderContainer(
      overrides: [
        storeSoundOutputProvider.overrideWithValue(output),
        storeSoundSettingStoreProvider.overrideWithValue(store),
        appLogProvider.overrideWithValue(log),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('sounds play when the setting is on', () async {
    final output = _RecordingSoundOutput();
    final container = containerWith(output, _MemorySettingStore(true));
    final player = container.read(storeSoundPlayerProvider);
    await player.playNow(StoreSound.addedToCart);
    await player.playNow(StoreSound.saleComplete);
    expect(output.played, [StoreSound.addedToCart, StoreSound.saleComplete]);
    expect(log.events, isEmpty);
  });

  test('no sound plays when the setting is off', () async {
    final output = _RecordingSoundOutput();
    final container = containerWith(output, _MemorySettingStore(false));
    await container.read(storeSoundPlayerProvider).playNow(StoreSound.notFound);
    expect(output.played, isEmpty);
  });

  test('turning the setting off stops later sounds', () async {
    final output = _RecordingSoundOutput();
    final store = _MemorySettingStore(true);
    final container = containerWith(output, store);
    await container.read(storeSoundsEnabledProvider.future);
    await container
        .read(storeSoundsEnabledProvider.notifier)
        .setEnabled(enabled: false);
    await container.read(storeSoundPlayerProvider).playNow(StoreSound.scanned);
    expect(output.played, isEmpty);
    expect(store.enabled, isFalse);
  });

  test('a sound that fails is logged, never thrown', () async {
    final output = _RecordingSoundOutput(
      failure: PlatformException(code: 'tone_failed'),
    );
    final container = containerWith(output, _MemorySettingStore(true));
    await container.read(storeSoundPlayerProvider).playNow(StoreSound.scanned);
    expect(log.events, ['sound.play']);
  });

  test('the setting is on by default and survives a restart', () async {
    final store = FileStoreSoundSettingStore(
      directoryProvider: () async => scratch,
    );
    expect(await store.read(), isTrue);
    await store.write(enabled: false);
    final reopened = FileStoreSoundSettingStore(
      directoryProvider: () async => scratch,
    );
    expect(await reopened.read(), isFalse);
  });

  test('a damaged setting file is reported, not read as a choice', () async {
    File('${scratch.path}/store_sounds.json')
        .writeAsStringSync('{"enabled":1}');
    final store = FileStoreSoundSettingStore(
      directoryProvider: () async => scratch,
    );
    await expectLater(store.read(), throwsFormatException);
  });

  test('quick toggles keep the last choice', () async {
    final store = FileStoreSoundSettingStore(
      directoryProvider: () async => scratch,
    );
    await Future.wait([
      store.write(enabled: false),
      store.write(enabled: true),
      store.write(enabled: false),
    ]);
    expect(await store.read(), isFalse);
  });

  test('a damaged setting is logged and sounds keep the default', () async {
    File('${scratch.path}/store_sounds.json').writeAsStringSync('not json');
    final output = _RecordingSoundOutput();
    final container = containerWith(
      output,
      FileStoreSoundSettingStore(directoryProvider: () async => scratch),
    );
    final player = container.read(storeSoundPlayerProvider);
    await player.playNow(StoreSound.scanned);
    await player.playNow(StoreSound.addedToCart);
    expect(output.played, [StoreSound.scanned, StoreSound.addedToCart]);
    expect(log.events, ['sound.setting']);
  });

  test('every sound has a name the Android side knows', () {
    final mainActivity = File(
      'android/app/src/main/java/com/tinda360/app/MainActivity.java',
    ).readAsStringSync();
    for (final sound in StoreSound.values) {
      expect(
        mainActivity,
        contains('TONES.put("${sound.wireName}", new int[]'),
        reason: sound.name,
      );
    }
  });
}
