import '../data/mock_data.dart';
import 'blind_tiger_models.dart';

/// Active drink menu — cloud `drink_catalog` with MockData fallback.
abstract final class DrinkCatalog {
  static List<Drink> _active = List<Drink>.from(MockData.drinks);

  static List<Drink> get active => List<Drink>.unmodifiable(_active);

  static void replaceCatalog(List<Drink> drinks) {
    if (drinks.isEmpty) {
      _active = List<Drink>.from(MockData.drinks);
      return;
    }
    _active = List<Drink>.from(drinks);
  }

  static Drink? bySlug(String slug) {
    final key = slug.trim().toLowerCase();
    for (final drink in _active) {
      if (drink.slug.toLowerCase() == key) return drink;
    }
    for (final drink in MockData.drinks) {
      if (drink.slug.toLowerCase() == key) return drink;
    }
    return null;
  }
}
