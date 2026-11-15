import 'dart:async';

String currentRoute() => '';

void pushRoute(String route) {}

Stream<String> get routeChanges => const Stream<String>.empty();

bool get isDocumentVisible => true;

Stream<bool> get visibilityChanges => const Stream<bool>.empty();

Future<void> toggleFullscreen() async {}

void printPage() {}
