import 'dart:async';

/// Subscribes to a stream ONCE and replays the latest value to every new
/// listener, so switching screens shows data immediately instead of a
/// spinner (and Firebase is not re-subscribed on every rebuild).
class LiveValue<T> {
  LiveValue(Stream<T> source) {
    _sub = source.listen(
      (v) {
        _value = v;
        _hasValue = true;
        _error = null;
        _controller.add(v);
      },
      onError: (Object e) {
        _error = e;
        _controller.addError(e);
      },
    );
  }

  final _controller = StreamController<T>.broadcast();
  late final StreamSubscription<T> _sub;
  T? _value;
  bool _hasValue = false;
  Object? _error;

  bool get hasValue => _hasValue;
  T? get value => _value;

  Stream<T> get stream async* {
    if (_hasValue) {
      yield _value as T;
    } else if (_error != null) {
      throw _error!;
    }
    yield* _controller.stream;
  }

  void dispose() {
    _sub.cancel();
    _controller.close();
  }
}
