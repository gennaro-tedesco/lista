import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/recipe_service.dart';
import 'recipe_detail_page.dart';

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
        _selectedRecipeId = null;
        _hasQueried = false;
      });
      return;
    }
    setState(() {
      _loadingRecipes = true;
      _recipeError = null;
      _recipes = [];
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
    });
    try {
      final recipe = await widget.recipeService.getRecipe(id);
      if (!mounted || id != _selectedRecipeId) return;
      setState(() => _loadingRecipe = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecipeDetailPage(
            recipe: recipe,
            onCreateList: widget.onCreateList,
          ),
        ),
      );
      if (!mounted || id != _selectedRecipeId) return;
      setState(() => _selectedRecipeId = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted && _loadingRecipe) {
        setState(() => _loadingRecipe = false);
      }
    }
  }

  void _selectAuthor(String? author) {
    if (author == null) return;
    setState(() {
      _selectedAuthor = author;
      _selectedRecipeId = null;
    });
    _loadRecipes();
  }

  void _selectRecipe(int? id) {
    if (id == null) return;
    setState(() => _selectedRecipeId = id);
    _loadRecipe(id);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintStyle =
        (theme.inputDecorationTheme.hintStyle ?? const TextStyle()).copyWith(
          color: theme.inputDecorationTheme.hintStyle?.color ?? theme.hintColor,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 128),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Expanded(
            child: _recipeError != null
                ? Align(
                    alignment: Alignment.topLeft,
                    child: FilledButton(
                      onPressed: _loadRecipes,
                      child: const Text('Retry'),
                    ),
                  )
                : _hasQueried && _recipes.isEmpty
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Text('No results', style: hintStyle),
                  )
                : ListView.separated(
                    itemCount: _recipes.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      final recipe = _recipes[index];
                      return InkWell(
                        onTap: !_loadingRecipe
                            ? () => _selectRecipe(recipe.id)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(recipe.name)),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
