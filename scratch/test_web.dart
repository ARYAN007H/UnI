import 'dart:js_interop';

@JS('window.navigator.storage.persist')
external JSPromise<JSBoolean> _persistStorage();

Future<bool> requestWebStorage() async {
  try {
    final result = await _persistStorage().toDart;
    return result.toDart;
  } catch (e) {
    return false;
  }
}

void main() {}
