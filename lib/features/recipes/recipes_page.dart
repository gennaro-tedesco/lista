import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/recipe_service.dart';

class RecipesPage extends StatefulWidget {
  final RecipeService recipeService;
  final Future<void> Function(Recipe recipe) onCreateList;

  RecipesPage({
    super.key,
    RecipeService? recipeService,
    required this.onCreateList,
  }) : recipeService = recipeService ?? RecipeService();

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  List<String> _authors = [];
  List<RecipeSummary> _recipes = [];
  Recipe? _selectedRecipe;
  String? _selectedAuthor;
  int? _selectedRecipeId;
  Object? _authorError;
  Object? _recipeError;
  bool _loadingAuthors = true;
  bool _loadingRecipes = false;
  bool _loadingRecipe = false;
  bool _hasQueried = false;
  bool _hasSearchText = false;

  final TextEditingController _searchController = TextEditingController();
  OverlayEntry? _menuOverlay;

  @override
  void initState() {
    super.initState();
    _loadAuthors();
  }

  @override
  void dispose() {
    _menuOverlay?.remove();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthors() async {
    setState(() {
      _loadingAuthors = true;
      _authorError = null;
    });
    try {
      final authors = await widget.recipeService.getAuthors();
      if (!mounted) return;
      setState(() {
        _authors = authors;
        _loadingAuthors = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _authorError = e;
        _loadingAuthors = false;
      });
    }
  }

  Future<void> _loadRecipes() async {
    final author = _selectedAuthor;
    final search = _searchController.text.trim();
    if (author == null && search.isEmpty) {
      setState(() {
        _recipes = [];
        _selectedRecipe = null;
        _selectedRecipeId = null;
        _hasQueried = false;
      });
      return;
    }
    setState(() {
      _loadingRecipes = true;
      _recipeError = null;
      _recipes = [];
      _selectedRecipe = null;
      _selectedRecipeId = null;
      _hasQueried = true;
    });
    try {
      final recipes = await widget.recipeService.getRecipes(
        author: author,
        search: search,
      );
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _loadingRecipes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recipeError = e;
        _loadingRecipes = false;
      });
    }
  }

  Future<void> _loadRecipe(int id) async {
    setState(() {
      _loadingRecipe = true;
      _selectedRecipe = null;
    });
    try {
      final recipe = await widget.recipeService.getRecipe(id);
      if (!mounted || id != _selectedRecipeId) return;
      setState(() => _selectedRecipe = recipe);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _loadingRecipe = false);
      }
    }
  }

  void _selectAuthor(String? author) {
    if (author == null) return;
    setState(() {
      _selectedAuthor = author;
      _selectedRecipe = null;
      _selectedRecipeId = null;
    });
    _loadRecipes();
  }

  void _selectRecipe(int? id) {
    if (id == null) return;
    setState(() => _selectedRecipeId = id);
    _loadRecipe(id);
  }

  Future<void> _openSourceUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid recipe URL')));
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open recipe URL')),
      );
    }
  }

  Future<T?> _openMenuAt<T>(
    BuildContext ctx,
    List<({T value, String label})> items,
  ) {
    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null) return Future.value(null);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final top = topLeft.dy + renderBox.size.height;
    final left = topLeft.dx;
    final width = renderBox.size.width;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.48;
    final completer = Completer<T?>();

    void close(T? value) {
      _menuOverlay?.remove();
      _menuOverlay = null;
      if (!completer.isCompleted) completer.complete(value);
    }

    _menuOverlay?.remove();
    _menuOverlay = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => close(null),
        child: Stack(
          children: [
            Positioned(
              top: top,
              left: left,
              width: width,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(4),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text('No results'),
                        )
                      : ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: items
                              .map(
                                (item) => InkWell(
                                  onTap: () => close(item.value),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Text(item.label),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_menuOverlay!);
    return completer.future;
  }

  Widget _buildCreateListButton(
    BuildContext context,
    Recipe recipe,
    Color fillColor,
  ) => SizedBox(
    width: 84,
    height: 56,
    child: FloatingActionButton(
      heroTag: 'recipe_list',
      onPressed: () => widget.onCreateList(recipe),
      backgroundColor: fillColor,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.add, size: 18),
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

  Widget _buildRecipePanel(
    BuildContext context,
    Recipe recipe,
    Color fillColor,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Dismissible(
        key: ValueKey(recipe.id),
        direction: DismissDirection.endToStart,
        background: Container(color: Colors.transparent),
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.error,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Icon(Icons.delete, color: theme.colorScheme.onError),
        ),
        onDismissed: (_) {
          setState(() {
            _selectedRecipe = null;
            _selectedRecipeId = null;
            _searchController.clear();
            _hasSearchText = false;
          });
          _loadRecipes();
        },
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    _buildCreateListButton(context, recipe, fillColor),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      ingredient.measure,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
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
                        Text(
                          'Instructions',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(recipe.instructions, textAlign: TextAlign.justify),
                        if (recipe.sourceUrl != null &&
                            recipe.sourceUrl!.trim().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Check it out!',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _openSourceUrl(recipe.sourceUrl!),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final hintStyle =
        (theme.inputDecorationTheme.hintStyle ?? const TextStyle()).copyWith(
          color: theme.inputDecorationTheme.hintStyle?.color ?? theme.hintColor,
        );
    final selectedRecipe = _selectedRecipe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 128),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      enabled: !_loadingRecipes && !_loadingRecipe,
                      decoration: InputDecoration(
                        hintText: 'Search by title...',
                        hintStyle: hintStyle,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                      onChanged: (v) =>
                          setState(() => _hasSearchText = v.isNotEmpty),
                      onSubmitted: (_) => _loadRecipes(),
                    ),
                  ),
                  Opacity(
                    opacity: _hasSearchText ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !_hasSearchText,
                      child: IconButton.filled(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _hasSearchText = false);
                          _loadRecipes();
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.14),
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(32, 32),
                          maximumSize: const Size(32, 32),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: !_loadingRecipes && !_loadingRecipe
                        ? _loadRecipes
                        : null,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.14),
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(32, 32),
                      maximumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.search, size: 18),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (ctx) => Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _loadingAuthors
                            ? null
                            : () async {
                                final selected = await _openMenuAt<String>(
                                  ctx,
                                  _authors
                                      .map((a) => (value: a, label: a))
                                      .toList(),
                                );
                                _selectAuthor(selected);
                              },
                        child: TextField(
                          enabled: false,
                          decoration: InputDecoration(
                            hintText: _selectedAuthor ?? 'Select author',
                            hintStyle: _selectedAuthor != null
                                ? DefaultTextStyle.of(context).style
                                : hintStyle,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: _selectedAuthor != null ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: _selectedAuthor == null,
                        child: IconButton.filled(
                          onPressed: () {
                            setState(() {
                              _selectedAuthor = null;
                              _recipes = [];
                              _selectedRecipe = null;
                              _selectedRecipeId = null;
                              _hasQueried = false;
                            });
                            _loadRecipes();
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.14),
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(32, 32),
                            maximumSize: const Size(32, 32),
                            padding: EdgeInsets.zero,
                          ),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _loadingAuthors
                          ? null
                          : () async {
                              final selected = await _openMenuAt<String>(
                                ctx,
                                _authors
                                    .map((a) => (value: a, label: a))
                                    .toList(),
                              );
                              _selectAuthor(selected);
                            },
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.14),
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(32, 32),
                        maximumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
          if (_authorError != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadAuthors, child: const Text('Retry')),
          ],
          const SizedBox(height: 16),
          if (_recipeError != null) ...[
            FilledButton(onPressed: _loadRecipes, child: const Text('Retry')),
            const SizedBox(height: 16),
          ] else if (_hasQueried && _recipes.isEmpty) ...[
            Text('No results', style: hintStyle),
            const SizedBox(height: 16),
          ] else if (_recipes.isNotEmpty)
            Builder(
              builder: (ctx) => Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 0,
                  ),
                  child: InkWell(
                    onTap: !_loadingRecipe
                        ? () async {
                            final selected = await _openMenuAt<int>(
                              ctx,
                              _recipes
                                  .map((r) => (value: r.id, label: r.name))
                                  .toList(),
                            );
                            _selectRecipe(selected);
                          }
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(enabled: !_loadingRecipe),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedRecipeId != null
                                  ? (_recipes
                                            .where(
                                              (r) => r.id == _selectedRecipeId,
                                            )
                                            .firstOrNull
                                            ?.name ??
                                        'Select recipe')
                                  : 'Select recipe',
                              style: _selectedRecipeId != null
                                  ? null
                                  : hintStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (_loadingRecipe)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (selectedRecipe != null)
            _buildRecipePanel(context, selectedRecipe, fillColor)
          else
            const Spacer(),
        ],
      ),
    );
  }
}
