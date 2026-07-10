import 'package:flutter/widgets.dart';

class TvFocusSystem {
  static final Map<String, FocusNode> _nodes = {};

  /// Retrieves or registers a FocusNode uniquely identified by [id].
  /// This prevents losing focus state when widgets rebuild.
  static FocusNode getNode(String id, {String? debugLabel}) {
    return _nodes.putIfAbsent(
      id,
      () => FocusNode(debugLabel: debugLabel ?? id),
    );
  }

  /// Disposes and removes nodes belonging to a specific screen or prefix.
  static void disposeScreen(String prefix) {
    final keysToRemove = _nodes.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      final node = _nodes.remove(key);
      node?.dispose();
    }
  }

  /// Disposes all registered nodes.
  static void disposeAll() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    _nodes.clear();
  }
}
