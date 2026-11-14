import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const TempoApp());
}

class TempoApp extends StatelessWidget {
  const TempoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF9E3F2E);
    return MaterialApp(
      title: 'tempo, tempo – fit in Formen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MigrationHomePage(),
    );
  }
}

class MigrationHomePage extends StatelessWidget {
  const MigrationHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('tempo, tempo')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Flutter-Web-Grundgerüst bereit',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hier beginnt die Dart-Portierung. Die bisherige '
                    'Web-Version und der Cloudflare-Worker bleiben bis zur '
                    'geplanten Umstellung unverändert verfügbar.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Übungen und Drehscheibe')),
                      Chip(label: Text('Verb- und Substantivdaten')),
                      Chip(label: Text('Shop und Rom')),
                      Chip(label: Text('Rangliste')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
