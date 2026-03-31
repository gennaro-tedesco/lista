import 'package:flutter_test/flutter_test.dart';
import 'package:lista/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ListaApp());
    expect(find.text('Lista'), findsOneWidget);
  });
}
