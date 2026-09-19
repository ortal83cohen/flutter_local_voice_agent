import 'dart:async';

import 'models.dart';

/// A single-listener stream whose paused delivery queue is bounded.
final class BoundedEventStream<T> {
  /// Creates a bounded stream with [capacity] queued notifications.
  BoundedEventStream({
    required this.capacity,
    required this.onOverflow,
    required this.terminalValue,
  }) : assert(capacity > 0) {
    _controller = StreamController<T>(
      sync: true,
      onListen: () => _listening = true,
      onPause: () => _paused = true,
      onResume: _flush,
      onCancel: () {
        _listening = false;
        _paused = false;
        _pending.clear();
      },
    );
  }

  /// Maximum number of paused notifications.
  final int capacity;

  /// Called once when the capacity is exceeded.
  final Future<void> Function() onOverflow;

  /// Creates the terminal value that replaces a paused backlog on overflow.
  final T Function() terminalValue;
  late final StreamController<T> _controller;
  final List<T> _pending = <T>[];
  bool _paused = false;
  bool _listening = false;
  bool _overflowed = false;

  /// The single-listener notification stream.
  Stream<T> get stream => _controller.stream;

  /// Adds an item or preserves a terminal capacity failure for a slow consumer.
  void add(T value) {
    if (_controller.isClosed || !_listening || _overflowed) {
      return;
    }
    if (!_paused) {
      _controller.add(value);
      return;
    }
    if (_pending.length >= capacity) {
      _overflowed = true;
      _pending
        ..clear()
        ..add(terminalValue());
      unawaited(onOverflow());
      return;
    }
    _pending.add(value);
  }

  /// Replaces paused backlog with one terminal item and invalidates the source.
  void fail(T terminalValue) {
    if (_controller.isClosed || !_listening || _overflowed) {
      return;
    }
    _overflowed = true;
    if (_paused) {
      _pending
        ..clear()
        ..add(terminalValue);
    } else {
      _controller.add(terminalValue);
    }
    unawaited(onOverflow());
  }

  void _flush() {
    _paused = false;
    while (!_paused && _pending.isNotEmpty && !_controller.isClosed) {
      _controller.add(_pending.removeAt(0));
    }
  }

  /// Closes the stream after pending delivery is discarded.
  Future<void> close() {
    _pending.clear();
    _controller.close();
    return Future<void>.value();
  }
}

/// Creates the terminal capacity failure used by stream owners.
AgentFailure capacityFailure() => const AgentFailure(
  AgentErrorCode.capacityExceeded,
  'The event consumer exceeded the bounded delivery capacity.',
  fatal: true,
);
