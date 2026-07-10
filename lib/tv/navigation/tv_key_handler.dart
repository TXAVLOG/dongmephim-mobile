import 'package:flutter/services.dart';

class TvKeyHandler {
  static bool isDpadUp(KeyEvent event) {
    return event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.arrowUp ||
         event.logicalKey == LogicalKeyboardKey.gameButton1); // standard mapping
  }

  static bool isDpadDown(KeyEvent event) {
    return event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.arrowDown ||
         event.logicalKey == LogicalKeyboardKey.gameButton2);
  }

  static bool isDpadLeft(KeyEvent event) {
    return event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
         event.logicalKey == LogicalKeyboardKey.gameButton3);
  }

  static bool isDpadRight(KeyEvent event) {
    return event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.arrowRight ||
         event.logicalKey == LogicalKeyboardKey.gameButton4);
  }

  static bool isDpadCenter(KeyEvent event) {
    return event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.select ||
         event.logicalKey == LogicalKeyboardKey.enter ||
         event.logicalKey == LogicalKeyboardKey.numpadEnter ||
         event.logicalKey == LogicalKeyboardKey.space);
  }

  static bool isMediaPlayPause(KeyEvent event) {
    return event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.mediaPlayPause ||
         event.logicalKey == LogicalKeyboardKey.mediaPlay ||
         event.logicalKey == LogicalKeyboardKey.mediaPause);
  }

  static bool isMediaFastForward(KeyEvent event) {
    return event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.mediaFastForward;
  }

  static bool isMediaRewind(KeyEvent event) {
    return event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.mediaRewind;
  }
}
