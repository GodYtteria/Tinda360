import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:tinda360/services/service_providers.dart';

enum StoreSound {
  scanned('scanned'),
  addedToCart('added_to_cart'),
  notFound('not_found'),
  outOfStock('out_of_stock'),
  saleComplete('sale_complete');

  new(this.wireName);

  final String wireName;
}

abstract interface class StoreSoundOutput {
  Future<void> play(StoreSound sound);
}

final class ToneChannelSoundOutput implements StoreSoundOutput {
  const new();

  static const MethodChannel _channel = MethodChannel('com.tinda360.app/tones');
  static const String _playMethod = 'play';
  static const String _soundArgument = 'sound';

  @override
  Future<void> play(StoreSound sound) => _channel.invokeMethod<void>(
    _playMethod,
    <String, String>{_soundArgument: sound.wireName},
  );
}

abstract interface class StoreSoundSettingStore {
  Future<bool> read();

  Future<void> write({required bool enabled});
}

final class FileStoreSoundSettingStore implements StoreSoundSettingStore {
  new({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const String _fileName = 'store_sounds.json';
  static const String _enabledKey = 'enabled';
  static const bool enabledByDefault = true;

  final Future<Directory> Function() _directoryProvider;
  Future<void> _lastWrite = Future<void>.value();

  @override
  Future<bool> read() async {
    final file = await _resolveFile();
    if (!file.existsSync()) return enabledByDefault;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> || decoded[_enabledKey] is! bool) {
      throw FormatException('store sound setting is malformed', decoded);
    }
    return decoded[_enabledKey] as bool;
  }

  @override
  Future<void> write({required bool enabled}) {
    final current = _lastWrite
        .catchError((Object _) {})
        .then((_) => _writeNow(enabled));
    _lastWrite = current;
    return current;
  }

  Future<void> _writeNow(bool enabled) async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(<String, bool>{_enabledKey: enabled}),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryProvider();
    return File(path.join(directory.path, _fileName));
  }
}

final storeSoundOutputProvider = Provider<StoreSoundOutput>(
  (ref) => const ToneChannelSoundOutput(),
);

final storeSoundSettingStoreProvider = Provider<StoreSoundSettingStore>(
  (ref) => FileStoreSoundSettingStore(),
);

final storeSoundsEnabledProvider =
    AsyncNotifierProvider<StoreSoundsEnabledNotifier, bool>(
      StoreSoundsEnabledNotifier.new,
    );

class StoreSoundsEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      return await ref.read(storeSoundSettingStoreProvider).read();
    } on Object catch (error, stack) {
      ref.read(appLogProvider).error('sound.setting', error, stack);
      return FileStoreSoundSettingStore.enabledByDefault;
    }
  }

  Future<void> setEnabled({required bool enabled}) async {
    final previous = state;
    state = AsyncData(enabled);
    try {
      await ref.read(storeSoundSettingStoreProvider).write(enabled: enabled);
    } on Object {
      state = previous;
      rethrow;
    }
  }
}

final storeSoundPlayerProvider = Provider<StoreSoundPlayer>(
  StoreSoundPlayer.new,
);

final class StoreSoundPlayer {
  new(this._ref);

  final Ref _ref;

  void play(StoreSound sound) => unawaited(playNow(sound));

  Future<void> playNow(StoreSound sound) async {
    if (!await _ref.read(storeSoundsEnabledProvider.future)) return;
    try {
      await _ref.read(storeSoundOutputProvider).play(sound);
    } on Object catch (error, stack) {
      _ref.read(appLogProvider).error('sound.play', error, stack);
    }
  }
}
