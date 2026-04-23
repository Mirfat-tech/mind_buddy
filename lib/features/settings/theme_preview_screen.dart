import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/home/overall_features_page.dart';
import 'package:mind_buddy/paper/paper_canvas.dart';
import 'package:mind_buddy/paper/paper_styles.dart';
import 'package:mind_buddy/paper/themed_page.dart';

class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key, required this.themeId});

  final String themeId;

  @override
  Widget build(BuildContext context) {
    final style = styleById(themeId);

    return Theme(
      data: buildThemeFromPaperStyle(style),
      child: PaperCanvas(
        style: style,
        child: MbScaffold(
          applyBackground: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(style.name, style: TextStyle(color: style.text)),
            leading: MbGlowBackButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/settings/appearance'),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'A little peek at how Home would feel in this theme.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: style.mutedText),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: style.border.withValues(alpha: 0.82),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: style.accent.withValues(alpha: 0.1),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const OverallFeaturesPage(previewMode: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: style.boxFill.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: style.border.withValues(alpha: 0.82),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: style.accent.withValues(alpha: 0.1),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      'This theme isn’t available on Free mode. Upgrade to Plus mode to unlock it.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: style.text.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
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
