import '../data/food_suggestions_data.dart';
import '../models/food_suggestion.dart';

class SuggestionService {
  static List<FoodSuggestion> getSuggestions(String query, {int limit = 6}) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();

    final prefixName = <FoodSuggestion>[];
    final prefixAlias = <FoodSuggestion>[];
    final substringMatches = <FoodSuggestion>[];

    for (final item in foodSuggestions) {
      if (item.name.toLowerCase().startsWith(q)) {
        prefixName.add(item);
      } else if (item.aliases.any((a) => a.toLowerCase().startsWith(q))) {
        prefixAlias.add(item);
      } else if (item.name.toLowerCase().contains(q) ||
          item.aliases.any((a) => a.toLowerCase().contains(q))) {
        substringMatches.add(item);
      }
    }

    return [...prefixName, ...prefixAlias, ...substringMatches]
        .take(limit)
        .toList();
  }
}
