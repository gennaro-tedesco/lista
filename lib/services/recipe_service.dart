import 'package:dio/dio.dart';

class RecipeCategory {
  final String id;
  final String name;

  const RecipeCategory({required this.id, required this.name});

  factory RecipeCategory.fromJson(Map<String, dynamic> json) => RecipeCategory(
    id: json['idCategory'] as String? ?? '',
    name: json['strCategory'] as String? ?? '',
  );
}

class RecipeSummary {
  final String id;
  final String name;

  const RecipeSummary({required this.id, required this.name});

  factory RecipeSummary.fromJson(Map<String, dynamic> json) => RecipeSummary(
    id: json['idMeal'] as String? ?? '',
    name: json['strMeal'] as String? ?? '',
  );
}

class Recipe {
  final String id;
  final String name;
  final List<RecipeIngredient> ingredients;
  final String instructions;

  const Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.instructions,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['idMeal'] as String? ?? '',
    name: json['strMeal'] as String? ?? '',
    ingredients:
        (List.generate(20, (index) {
          final number = index + 1;
          final name = (json['strIngredient$number'] as String? ?? '').trim();
          final measure = (json['strMeasure$number'] as String? ?? '').trim();
          return RecipeIngredient(name: name, measure: measure);
        }).where((ingredient) => ingredient.name.isNotEmpty).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        )),
    instructions: json['strInstructions'] as String? ?? '',
  );
}

class RecipeIngredient {
  final String name;
  final String measure;

  const RecipeIngredient({required this.name, required this.measure});
}

class RecipeService {
  final Dio _dio;

  RecipeService({Dio? dio})
    : _dio =
          dio ??
          Dio(BaseOptions(baseUrl: 'https://www.themealdb.com/api/json/v1/1'));

  Future<List<RecipeCategory>> getCategories() async {
    final response = await _dio.get<Map<String, dynamic>>('/categories.php');
    final categories = response.data?['categories'] as List<dynamic>? ?? [];
    return categories
        .map((item) => RecipeCategory.fromJson(item as Map<String, dynamic>))
        .where((category) => category.id.isNotEmpty && category.name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<List<RecipeSummary>> getRecipes(String category) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/filter.php',
      queryParameters: {'c': category},
    );
    final meals = response.data?['meals'] as List<dynamic>? ?? [];
    return meals
        .map((item) => RecipeSummary.fromJson(item as Map<String, dynamic>))
        .where((recipe) => recipe.id.isNotEmpty && recipe.name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<Recipe> getRecipe(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/lookup.php',
      queryParameters: {'i': id},
    );
    final meals = response.data?['meals'] as List<dynamic>? ?? [];
    if (meals.isEmpty) {
      throw Exception('Recipe not found');
    }
    return Recipe.fromJson(meals.first as Map<String, dynamic>);
  }
}
