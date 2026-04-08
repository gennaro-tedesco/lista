import '../data/food_suggestions_data.dart';
import '../models/food_suggestion.dart';

class SuggestionService {
  static List<FoodSuggestion> getSuggestions(String query, {int limit = 6}) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    final normalizedQuery = _normalize(q);
    final exactMatches = <FoodSuggestion>[];
    final singularPluralMatches = <FoodSuggestion>[];
    final prefixMatches = <FoodSuggestion>[];

    for (final item in foodSuggestions) {
      final name = item.name.toLowerCase();
      final normalizedName = _normalize(name);
      if (name == q) {
        exactMatches.add(item);
      } else if (normalizedName == normalizedQuery) {
        singularPluralMatches.add(item);
      } else if (name.startsWith(q) ||
          normalizedName.startsWith(normalizedQuery)) {
        prefixMatches.add(item);
      }
    }

    return [
      ...exactMatches,
      ...singularPluralMatches,
      ...prefixMatches,
    ].take(limit).toList();
  }

  static String? categoryFor(String value) {
    final query = value.toLowerCase().trim();
    if (query.isEmpty) return null;

    final normalizedQuery = _normalize(query);

    for (final item in foodSuggestions) {
      final name = item.name.toLowerCase();
      if (name == query || _normalize(name) == normalizedQuery) {
        return item.category;
      }
    }

    FoodSuggestion? best;
    for (final item in foodSuggestions) {
      final name = item.name.toLowerCase();
      final normalizedName = _normalize(name);
      if (_containsWord(query, name) ||
          _containsWord(normalizedQuery, normalizedName)) {
        if (best == null || name.length > best.name.toLowerCase().length) {
          best = item;
        }
      }
    }
    return best?.category;
  }

  static bool _containsWord(String text, String word) {
    final idx = text.indexOf(word);
    if (idx == -1) return false;
    final before = idx == 0 || text[idx - 1] == ' ';
    final after =
        idx + word.length == text.length || text[idx + word.length] == ' ';
    return before && after;
  }

  static String _normalize(String value) {
    final parts = value.split(' ');
    if (parts.isEmpty) return value;
    parts[parts.length - 1] = _normalizeWord(parts.last);
    return parts.join(' ');
  }

  static String _normalizeWord(String value) {
    if (value.endsWith('ies') && value.length > 3) {
      return '${value.substring(0, value.length - 3)}y';
    }
    if (value.endsWith('oes') && value.length > 3) {
      return value.substring(0, value.length - 2);
    }
    if ((value.endsWith('ches') ||
            value.endsWith('shes') ||
            value.endsWith('xes') ||
            value.endsWith('zes') ||
            value.endsWith('sses')) &&
        value.length > 2) {
      return value.substring(0, value.length - 2);
    }
    if (value.endsWith('s') && !value.endsWith('ss') && value.length > 1) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}
