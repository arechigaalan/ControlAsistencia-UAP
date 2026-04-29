import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class SonidoService {
  static Future<void> sonidoExito() async {
    try {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.play(AssetSource('sounds/success_beep.wav'));
      p.onPlayerComplete.listen((_) async {
        await p.dispose();
      });
    } catch (_) {}
  }

  static Future<void> sonidoError() async {
    try {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.play(AssetSource('sounds/error_beep.wav'));
      p.onPlayerComplete.listen((_) async {
        await p.dispose();
      });
    } catch (_) {}
  }

  static Future<void> vibrar() async {
    try {
      await HapticFeedback.heavyImpact();
      final tieneVibracion = await Vibration.hasVibrator();
      if (tieneVibracion == true) {
        await Vibration.vibrate(duration: 120);
      }
    } catch (_) {}
  }
}