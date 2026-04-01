const List<String> kCategoryOrder = [
  'Fruit',
  'Vegetable',
  'Drinks',
  'Meat',
  'Fish & Seafood',
  'Dairy',
  'Bakery',
  'Pantry',
  'Other',
];

class FoodSuggestion {
  final String name;
  final String category;

  const FoodSuggestion({required this.name, required this.category});
}
