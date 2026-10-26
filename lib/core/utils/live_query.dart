import 'dart:async';
import 'package:flutter/foundation.dart';
import '../errors/app_failure.dart';

/// Owns one listener and gives initial server lookups a bounded loading state.
class LiveQuery<T> extends ChangeNotifier {
  LiveQuery(this._source) {
    retry();
  }
  final Stream<T> Function() _source;
  StreamSubscription<T>? _subscription;
  Timer? _timeout;
  T? value;
  bool loading = true;
  AppFailure? failure;
  bool _disposed = false;
  int _generation = 0;
  void retry() {
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _timeout?.cancel();
    loading = true;
    failure = null;
    value = null;
    notifyListeners();
    void fail(Object error) {
      if (_disposed || generation != _generation) return;
      _timeout?.cancel();
      loading = false;
      failure = AppFailure.from(error);
      value = null;
      notifyListeners();
    }

    _timeout = Timer(
      const Duration(seconds: 20),
      () => fail(
        const AppFailure(
          'Unable to load data. Check your connection and retry.',
        ),
      ),
    );
    try {
      _subscription = _source().listen(
        (data) {
          if (_disposed || generation != _generation) return;
          _timeout?.cancel();
          value = data;
          loading = false;
          failure = null;
          notifyListeners();
        },
        onError: fail,
        onDone: () => fail(const AppFailure('Updates stopped. Please retry.')),
      );
    } catch (error) {
      fail(error);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timeout?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
