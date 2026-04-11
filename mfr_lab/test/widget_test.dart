import 'package:flutter_test/flutter_test.dart';
import 'package:mfr_lab/main.dart';
import 'package:provider/provider.dart';
import 'package:mfr_lab/providers/experiment_provider.dart';

void main() {
  testWidgets('App smoke test — renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ExperimentProvider(),
        child: const MFRVirtualLabApp(),
      ),
    );
    expect(find.text('MFR Virtual Lab — Setup'), findsOneWidget);
  });
}
