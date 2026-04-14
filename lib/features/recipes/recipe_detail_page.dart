import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/ui_sizes.dart';
import '../../services/recipe_service.dart';

class RecipeDetailPage extends StatelessWidget {
  final Recipe recipe;
  final Future<void> Function(Recipe recipe) onCreateList;

  const RecipeDetailPage({
    super.key,
    required this.recipe,
    required this.onCreateList,
  });

  Future<void> _openSourceUrl(BuildContext context, String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid recipe URL')));
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open recipe URL')),
      );
    }
  }

  Widget _buildCreateListButton(BuildContext context, Color fillColor) =>
      SizedBox(
        width: 84,
        height: 56,
        child: FloatingActionButton(
          heroTag: 'recipe_list',
          onPressed: () async {
            await onCreateList(recipe);
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          backgroundColor: fillColor,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: AppIconSize.inlineAction),
              const SizedBox(width: 4),
              SizedBox(
                width: 35,
                height: 35,
                child: OverflowBox(
                  maxWidth: 88,
                  maxHeight: 88,
                  child: SizedBox(
                    width: 45,
                    height: 45,
                    child: Image.asset('images/logo.png', fit: BoxFit.cover),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final backButtonStyle = IconButton.styleFrom(
      backgroundColor: theme.colorScheme.onSurfaceVariant.withValues(
        alpha: 0.14,
      ),
      foregroundColor: theme.colorScheme.onSurfaceVariant,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: AppConstraints.compactButton,
      maximumSize: AppConstraints.compactButton,
      padding: EdgeInsets.zero,
    );

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          recipe.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildCreateListButton(context, fillColor),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 56),
                  children: [
                    Text('Ingredients', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...recipe.ingredients.map(
                      (ingredient) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(ingredient.name)),
                            if (ingredient.measure.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  ingredient.measure,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Instructions', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(recipe.instructions, textAlign: TextAlign.justify),
                    if (recipe.sourceUrl != null &&
                        recipe.sourceUrl!.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Check it out!', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _openSourceUrl(context, recipe.sourceUrl!),
                        child: Text(
                          recipe.sourceUrl!,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton.filled(
                      onPressed: () => Navigator.of(context).pop(),
                      style: backButtonStyle,
                      icon: const Icon(
                        LucideIcons.chevron_left,
                        size: AppIconSize.toolbar,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
