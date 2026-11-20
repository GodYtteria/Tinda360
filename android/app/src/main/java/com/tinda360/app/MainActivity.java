package com.tinda360.app;

import android.media.AudioManager;
import android.media.ToneGenerator;
import android.os.Handler;
import android.os.Looper;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;

public class MainActivity extends FlutterFragmentActivity {
    private static final String TONE_CHANNEL = "com.tinda360.app/tones";
    private static final String PLAY_METHOD = "play";
    private static final String SOUND_ARGUMENT = "sound";
    private static final String UNKNOWN_SOUND_ERROR = "unknown_sound";
    private static final String TONE_FAILED_ERROR = "tone_failed";
    private static final int TONE_VOLUME = 80;
    private static final int RELEASE_MARGIN_MILLISECONDS = 100;
    private static final Map<String, int[]> TONES = new HashMap<>();

    static {
        TONES.put("scanned", new int[] {ToneGenerator.TONE_PROP_BEEP, 120});
        TONES.put("added_to_cart", new int[] {ToneGenerator.TONE_PROP_BEEP, 120});
        TONES.put("not_found", new int[] {ToneGenerator.TONE_PROP_NACK, 300});
        TONES.put("sale_complete", new int[] {ToneGenerator.TONE_PROP_ACK, 400});
    }

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), TONE_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (!PLAY_METHOD.equals(call.method)) {
                    result.notImplemented();
                    return;
                }
                String soundName = call.argument(SOUND_ARGUMENT);
                int[] tone = soundName == null ? null : TONES.get(soundName);
                if (tone == null) {
                    result.error(UNKNOWN_SOUND_ERROR, soundName, null);
                    return;
                }
                try {
                    playTone(tone[0], tone[1]);
                    result.success(null);
                } catch (RuntimeException error) {
                    result.error(TONE_FAILED_ERROR, error.getMessage(), null);
                }
            });
    }

    private void playTone(int toneType, int durationMilliseconds) {
        ToneGenerator generator = new ToneGenerator(AudioManager.STREAM_MUSIC, TONE_VOLUME);
        generator.startTone(toneType, durationMilliseconds);
        mainHandler.postDelayed(generator::release, durationMilliseconds + RELEASE_MARGIN_MILLISECONDS);
    }
}
