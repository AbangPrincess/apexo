import 'dart:async';

/// A value that streams its current state to each new listener, then every
/// change, the way a Firestore snapshot listener behaves.
class LiveValue<T> {
  LiveValue(this._value);

  T _value;
  final _changes = StreamController<T>.broadcast(sync: true);

  T get value => _value;

  set value(T next) {
    _value = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  Stream<T> get stream {
    StreamSubscription<T>? sub;
    late final StreamController<T> out;
    out = StreamController<T>(
      onListen: () {
        out.add(_value);
        sub = _changes.stream.listen(out.add);
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  void close() => _changes.close();
}
