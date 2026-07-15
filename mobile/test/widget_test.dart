import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app.dart';

void main() {
  testWidgets('MyRunnerApp affiche l\'écran de login au démarrage', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyRunnerApp()));
    await tester.pumpAndSettle();

    expect(find.text('MyRunner'), findsOneWidget);
    expect(find.text('Se connecter avec Strava'), findsOneWidget);
  });
}
