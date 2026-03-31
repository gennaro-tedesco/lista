class FoodSuggestion {
  final String name;
  final String emoji;
  final List<String> aliases;

  const FoodSuggestion({
    required this.name,
    required this.emoji,
    this.aliases = const [],
  });
}
