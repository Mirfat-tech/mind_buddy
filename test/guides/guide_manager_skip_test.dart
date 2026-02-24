import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('single tap on Skip dismisses instruction card', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _InstructionCardHarness()));

    expect(find.text('Instruction Card'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Instruction Card'), findsNothing);
    expect(find.text('Skip'), findsNothing);
  });
}

class _InstructionCardHarness extends StatefulWidget {
  const _InstructionCardHarness();

  @override
  State<_InstructionCardHarness> createState() =>
      _InstructionCardHarnessState();
}

class _InstructionCardHarnessState extends State<_InstructionCardHarness> {
  bool isDismissing = false;
  bool visible = true;

  Future<void> _onSkipPressed() async {
    if (isDismissing || !visible) return;
    setState(() {
      isDismissing = true;
      visible = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() {
      isDismissing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: visible
            ? Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Instruction Card'),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: isDismissing ? null : _onSkipPressed,
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
