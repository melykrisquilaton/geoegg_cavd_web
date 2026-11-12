
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoegg_cavd_web/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('GeoEgg CAVD login screen displays correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('GeoEgg'), findsOneWidget);
    expect(find.text('CAVD ADMINISTRATION PORTAL'), findsOneWidget);
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('CAVD Administrator Access Only'), findsOneWidget);

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
