import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/sharing/share_content.dart';
import 'package:steam_app/features/sharing/share_flyer.dart';

Future<void> _pump(WidgetTester tester, ShareContent content, {double textScale = 1}) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(800, 1000), textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: Center(child: ShareFlyer(content: content))),
      ),
    ),
  );
}

void main() {
  const long = 'A very long headline about the annual fatherhood and faith speaker series hosted by the club';
  final blurb = List.filled(60, 'Join us for an evening of talks and fellowship.').join(' ');

  testWidgets('lays out without overflow: long title, place, blurb, no photo', (tester) async {
    await _pump(
      tester,
      ShareContent(
        kicker: 'Guest Speaker',
        title: long,
        dateLine: 'Fri, Oct 9, 2026 · 6:30 PM – 8:00 PM',
        locationLine: 'St. Edward Parish Hall, 1234 Some Very Long Street Name, New Orleans, Louisiana',
        blurb: blurb,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ShareFlyer)), flyerSize);
  });

  testWidgets('ignores large system text size and short content', (tester) async {
    await _pump(tester, const ShareContent(kicker: 'Announcement', title: 'Hi'), textScale: 2.5);
    expect(tester.takeException(), isNull);
  });
}
