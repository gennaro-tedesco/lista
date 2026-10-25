import 'package:flutter_test/flutter_test.dart';
import 'package:lista/services/suggestion_service.dart';
import 'package:lista/utils/category_utils.dart';

void main() {
  test('exact categories take priority over singular and plural matches', () {
    expect(SuggestionService.categoryFor('pepper'), 'Spices');
    expect(SuggestionService.categoryFor('peppers'), 'Vegetable');
    expect(SuggestionService.categoryFor('bell pepper'), 'Vegetable');
    expect(SuggestionService.categoryFor('oat milk'), 'Drinks');
    expect(SuggestionService.categoryFor('canned tomatoes'), 'Pantry');
  });

  test('paper products map to Household', () {
    for (final name in ['Kitchen paper', 'Kitchen towel', 'Toilet Paper']) {
      expect(SuggestionService.categoryFor(name), 'Household');
    }
    expect(kCategoryOrder, contains('Household'));
  });
}
