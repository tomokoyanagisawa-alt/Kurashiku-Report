import 'package:flutter_test/flutter_test.dart';

import 'package:kurashiku_report/main.dart';

void main() {
  testWidgets('App launches and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const KurashikuReportApp());
    await tester.pump();

    expect(find.text('くらしくレポート'), findsOneWidget);
  });
}
