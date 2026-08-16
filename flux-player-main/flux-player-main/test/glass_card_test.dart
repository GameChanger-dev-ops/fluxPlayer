import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux_player/core/widgets/glass_card.dart';

void main() {
  testWidgets('GlassCard renders child inside a blurred glass surface',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: GlassCard(
          padding: EdgeInsets.all(8),
          child: Text('hello'),
        ),
      ),
    ));

    expect(find.text('hello'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(ClipRRect), findsWidgets);
  });
}
