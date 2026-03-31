import '../data/food_suggestions_data.dart';
import '../models/food_suggestion.dart';

class SuggestionService {
  static List<FoodSuggestion> getSuggestions(String query, {int limit = 6}) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    final exactMatches = <FoodSuggestion>[];
    final singularPluralMatches = <FoodSuggestion>[];
    final prefixMatches = <FoodSuggestion>[];
    final singularQuery = _singularize(q);
    final pluralQuery = _pluralize(q);

    for (final item in foodSuggestions) {
      final name = item.name.toLowerCase();
      if (name == q) {
        exactMatches.add(item);
      } else if (name == singularQuery || name == pluralQuery) {
        singularPluralMatches.add(item);
      } else if (name.startsWith(q)) {
        prefixMatches.add(item);
      }
    }

    return [...exactMatches, ...singularPluralMatches, ...prefixMatches]
        .take(limit)
        .toList();
  }

  static String _singularize(String value) {
    if (value.endsWith('ies') && value.length > 3) {
      return '${value.substring(0, value.length - 3)}y';
    }
    if (value.endsWith('es') && value.length > 2) {
      return value.substring(0, value.length - 2);
    }
    if (value.endsWith('s') && value.length > 1) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  static String _pluralize(String value) {
    if (value.endsWith('y') && value.length > 1) {
      return '${value.substring(0, value.length - 1)}ies';
    }
    if (value.endsWith('s')) {
      return value;
    }
    return '${value}s';
  }
}
