import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeSummary {
  final int id;
  final String name;

  const RecipeSummary({required this.id, required this.name});
}

class Recipe {
  final int id;
  final String name;
  final List<RecipeIngredient> ingredients;
  final String instructions;
  final String? sourceUrl;

  const Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.instructions,
    required this.sourceUrl,
  });
}

class RecipeIngredient {
  final String name;
  final String measure;

  const RecipeIngredient({required this.name, required this.measure});
}

class RecipeService {
  final SupabaseClient _client;

  RecipeService() : _client = Supabase.instance.client;

  Future<List<String>> getAuthors() async {
    final data = await _client.from('recipes').select('author').order('author');
    final authors = data
        .map((r) => r['author'] as String?)
        .whereType<String>()
        .map((author) => author.trim())
        .where((author) => author.isNotEmpty)
        .toSet()
        .toList();
    authors.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return authors;
  }

  Future<List<RecipeSummary>> getRecipes({
    String? author,
    String search = '',
  }) async {
    var query = _client.from('recipes').select('id, title');
    if (author != null) {
      query = query.eq('author', author);
    }
    if (search.isNotEmpty) {
      query = query.ilike('title', '%$search%');
    }
    final data = await query.order('title', ascending: true).limit(100);
    final recipes =
        (data
              .map(
                (r) => RecipeSummary(
                  id: r['id'] as int,
                  name: r['title'] as String,
                ),
              )
              .toList())
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return recipes;
  }

  Future<Recipe> getRecipe(int id) async {
    final row = await _client.from('recipes').select().eq('id', id).single();
    final ingredients =
        (row['ingredients'] as List<dynamic>)
            .map(
              (i) => RecipeIngredient(
                name: i['ingredient'] as String,
                measure: i['quantity'] as String? ?? '',
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return Recipe(
      id: row['id'] as int,
      name: row['title'] as String,
      ingredients: ingredients,
      instructions: row['description'] as String? ?? '',
      sourceUrl: row['source_url'] as String?,
    );
  }
}
