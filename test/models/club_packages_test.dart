import 'package:flutter_test/flutter_test.dart';

import 'package:in_time_bartender/models/club_packages.dart';

void main() {
  tearDown(ClubPackages.resetCatalog);

  test('defaults match seed catalog shape', () {
    expect(ClubPackages.defaults, hasLength(4));
    expect(ClubPackages.bySlug('standard-night')?.includedDrinks, 4);
    expect(ClubPackages.bySlug('unlimited')?.durationMinutes, isNull);
    expect(ClubPackages.bySlug('unlimited')?.includedDrinks, isNull);
  });

  test('fromSupabaseRow maps null allowances', () {
    final pkg = ClubPackage.fromSupabaseRow({
      'slug': 'unlimited',
      'name': 'Unlimited',
      'price_peso': 1799,
      'duration_minutes': null,
      'included_drinks': null,
      'target_guest': 'VIP / Members',
      'tagline': 'Invest your time wisely.',
      'popular': false,
      'sort_order': 4,
      'active': true,
    });
    expect(pkg.isUnlimited, isTrue);
    expect(pkg.includedDrinks, isNull);
    expect(pkg.drinksLabel, 'Unlimited*');
  });

  test('replaceCatalog drives all + bySlug with defaults fallback', () {
    ClubPackages.replaceCatalog([
      const ClubPackage(
        slug: 'quick-escape',
        name: 'Quick Escape Edited',
        pricePeso: 750,
        durationMinutes: 90,
        includedDrinks: 0,
        targetGuest: 'After-work',
        tagline: 'Edited.',
      ),
    ]);

    expect(ClubPackages.all, hasLength(1));
    expect(ClubPackages.bySlug('quick-escape')?.pricePeso, 750);
    expect(ClubPackages.bySlug('quick-escape')?.includedDrinks, 0);
    // Historical slug still resolves from defaults when absent from live catalog.
    expect(ClubPackages.bySlug('standard-night')?.name, 'Standard Night');
  });

  test('replaceCatalog empty restores defaults', () {
    ClubPackages.replaceCatalog(const []);
    expect(ClubPackages.all, hasLength(ClubPackages.defaults.length));
  });
}
