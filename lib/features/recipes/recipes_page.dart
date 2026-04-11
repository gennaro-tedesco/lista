import 'dart:async';
import 'package:flutter/material.dart';
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
  List<RecipeCategory> _categories = [];
  List<RecipeSummary> _recipes = [];
  Recipe? _selectedRecipe;
  String? _selectedCategory;
  String? _selectedRecipeId;
  Object? _categoryError;
  Object? _recipeError;
  bool _loadingCategories = true;
  bool _loadingRecipes = false;
  bool _loadingRecipe = false;

  final GlobalKey _categoryKey = GlobalKey();
  final GlobalKey _recipeKey = GlobalKey();
  OverlayEntry? _menuOverlay;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _menuOverlay?.remove();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
    });
    try {
      final categories = await widget.recipeService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categoryError = e;
        _loadingCategories = false;
      });
    }
  }

  Future<void> _loadRecipes(String category) async {
    setState(() {
      _loadingRecipes = true;
      _recipeError = null;
      _recipes = [];
      _selectedRecipe = null;
      _selectedRecipeId = null;
    });
    try {
      final recipes = await widget.recipeService.getRecipes(category);
      if (!mounted || category != _selectedCategory) return;
      setState(() {
        _recipes = recipes;
        _loadingRecipes = false;
      });
    } catch (e) {
      if (!mounted || category != _selectedCategory) return;
      setState(() {
        _recipeError = e;
        _loadingRecipes = false;
      });
    }
  }

  Future<void> _loadRecipe(String id) async {
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

  void _selectCategory(String? category) {
    if (category == null) return;
    setState(() => _selectedCategory = category);
    _loadRecipes(category);
  }

  void _selectRecipe(String? id) {
    if (id == null) return;
    setState(() => _selectedRecipeId = id);
    _loadRecipe(id);
  }

  Future<T?> _openMenu<T>(
    GlobalKey key,
    List<({T value, String label})> items,
  ) {
    final renderBox = key.currentContext?.findRenderObject();
    if (renderBox is! RenderBox) return Future.value(null);
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
                  child: ListView(
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

  Future<void> _openCategoryMenu() async {
    final selected = await _openMenu<String>(
      _categoryKey,
      _categories.map((c) => (value: c.name, label: c.name)).toList(),
    );
    _selectCategory(selected);
  }

  Future<void> _openRecipeMenu() async {
    final selected = await _openMenu<String>(
      _recipeKey,
      _recipes.map((r) => (value: r.id, label: r.name)).toList(),
    );
    _selectRecipe(selected);
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
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: theme.textTheme.titleMedium,
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
                                Expanded(
                                  child: Text(
                                    ingredient.name,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
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
                        Text(
                          recipe.instructions,
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
    final categoryEnabled =
        !_loadingCategories && _categoryError == null && _categories.isNotEmpty;
    final recipeEnabled =
        _selectedCategory != null &&
        !_loadingRecipes &&
        !_loadingRecipe &&
        _recipeError == null &&
        _recipes.isNotEmpty;
    final selectedRecipe = _selectedRecipe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 128),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                key: _categoryKey,
                onTap: categoryEnabled ? _openCategoryMenu : null,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(enabled: categoryEnabled),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedCategory ?? 'Select category',
                          style: _selectedCategory != null ? null : hintStyle,
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
          if (_loadingCategories) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ] else if (_categoryError != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadCategories,
              child: const Text('Retry'),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                key: _recipeKey,
                onTap: recipeEnabled ? _openRecipeMenu : null,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(enabled: recipeEnabled),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedRecipeId != null
                              ? (_recipes
                                        .where((r) => r.id == _selectedRecipeId)
                                        .firstOrNull
                                        ?.name ??
                                    'Select recipe')
                              : 'Select recipe',
                          style: _selectedRecipeId != null ? null : hintStyle,
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
          if (_loadingRecipes) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ] else if (_recipeError != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _loadRecipes(_selectedCategory!),
              child: const Text('Retry'),
            ),
          ],
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
