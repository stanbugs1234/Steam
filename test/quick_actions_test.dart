import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/home/presentation/quick_actions.dart';

const _labels = ['News', 'Events', 'Volunteer', 'Directory', 'Check In'];

Widget _app({required double width, double textScale = 1.0}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: QuickActionGrid(
                actions: [
                  for (final l in _labels)
                    QuickActionItem(icon: Icons.circle, label: l, onTap: () {}, badgeCount: l == 'Volunteer' ? 4 : 0),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Number of distinct rows the five tiles land in.
int _rows(WidgetTester tester) {
  final tops = {for (final l in _labels) tester.getTopLeft(find.byType(Card).at(_labels.indexOf(l))).dy.round()};
  return tops.length;
}

void main() {
  group('columnsFor', () {
    test('a typical phone keeps all five in one row', () {
      expect(QuickActionGrid.columnsFor(width: 353, textScale: 1, count: 5), 5); // 393pt phone
      expect(QuickActionGrid.columnsFor(width: 390, textScale: 1, count: 5), 5);
    });
    test('a 375pt phone (the one in the screenshot) still fits one row', () {
      expect(QuickActionGrid.columnsFor(width: 335, textScale: 1, count: 5), 5);
    });
    test('a very small phone flows into rows of three', () {
      expect(QuickActionGrid.columnsFor(width: 280, textScale: 1, count: 5), 3);
    });
    test('enlarged text flows into rows of three even on a wide phone', () {
      expect(QuickActionGrid.columnsFor(width: 390, textScale: 1.6, count: 5), 3);
    });
  });

  for (final width in [320.0, 360.0, 375.0, 393.0, 430.0, 768.0]) {
    for (final scale in [0.85, 1.0, 1.3, 1.8, 3.0]) {
      testWidgets('width $width at text scale $scale: no overflow, all five labels shown', (tester) async {
        await tester.pumpWidget(_app(width: width, textScale: scale));

        expect(tester.takeException(), isNull, reason: 'a layout overflow would be reported here');
        for (final label in _labels) {
          expect(find.text(label), findsOneWidget);
          // Every label must be a single unbroken line: taller than one line
          // of its own text would mean it wrapped mid-word.
          final size = tester.getSize(find.text(label));
          final style = tester.widget<Text>(find.text(label)).style;
          final oneLine = (style?.fontSize ?? 12) * scale * 2;
          expect(size.height, lessThan(oneLine), reason: '$label wrapped');
        }
      });
    }
  }

  testWidgets('375pt phone at normal text: one row, like the design', (tester) async {
    await tester.pumpWidget(_app(width: 375));
    expect(_rows(tester), 1);
  });

  testWidgets('375pt phone with large text: rows of three, so labels have room', (tester) async {
    await tester.pumpWidget(_app(width: 375, textScale: 1.8));
    expect(_rows(tester), 2);
  });

  testWidgets('the volunteers-needed badge is still shown', (tester) async {
    await tester.pumpWidget(_app(width: 375));
    expect(find.text('4'), findsOneWidget);
  });
}
