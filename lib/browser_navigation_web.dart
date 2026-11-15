import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

final StreamController<String> _routes = StreamController<String>.broadcast();
final StreamController<bool> _visibility = StreamController<bool>.broadcast();
final JSFunction _hashChange = ((web.Event _) {
  _routes.add(currentRoute());
}).toJS;
final JSFunction _visibilityChange = ((web.Event _) {
  _visibility.add(isDocumentVisible);
}).toJS;
bool _listening = false;
bool _visibilityListening = false;

String currentRoute() => web.window.location.hash.replaceFirst('#', '');

bool get isDocumentVisible => web.document.visibilityState == 'visible';

void pushRoute(String route) {
  web.window.location.hash = '#$route';
}

Stream<String> get routeChanges {
  if (!_listening) {
    web.window.addEventListener('hashchange', _hashChange);
    _listening = true;
  }
  return _routes.stream;
}

Stream<bool> get visibilityChanges {
  if (!_visibilityListening) {
    web.document.addEventListener('visibilitychange', _visibilityChange);
    _visibilityListening = true;
  }
  return _visibility.stream;
}

Future<void> toggleFullscreen() async {
  final document = web.document;
  if (document.fullscreenElement != null) {
    await document.exitFullscreen().toDart;
  } else {
    await document.documentElement!.requestFullscreen().toDart;
  }
}

void printPage() => web.window.print();
