import '../data/food_suggestions_data.dart';
import '../models/food_suggestion.dart';
import '../utils/category_utils.dart';

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

    if (best != null) {
      return best.category;
    }

    for (final category in kCategoryOrder) {
      final lowerCategory = category.toLowerCase();
      final normalizedCategory = _normalize(lowerCategory);
      if (lowerCategory == query || normalizedCategory == normalizedQuery) {
        return category;
      }
      if (_containsWord(query, lowerCategory) ||
          _containsWord(normalizedQuery, normalizedCategory) ||
          _containsWord(lowerCategory, query) ||
          _containsWord(normalizedCategory, normalizedQuery)) {
        return category;
      }
    }

    return null;
  }

  static bool _containsWord(String text, String word) {
    final textParts = _splitWords(text);
    final wordParts = _splitWords(word);
    if (textParts.isEmpty ||
        wordParts.isEmpty ||
        wordParts.length > textParts.length) {
      return false;
    }

    for (var index = 0; index <= textParts.length - wordParts.length; index++) {
      var matches = true;
      for (var offset = 0; offset < wordParts.length; offset++) {
        if (textParts[index + offset] != wordParts[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return true;
      }
    }

    return false;
  }

  static List<String> _splitWords(String value) {
    return value
        .split(RegExp(r'[^a-z0-9]+'))
        .where((part) => part.isNotEmpty)
        .toList();
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
