import 'package:cookbook/src/models/recipe.dart';
import 'package:cookbook/src/scaling/serving_scaler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatNumber (non-countable, §7 rounding rules)', () {
    test('>= 10 rounds to integer', () {
      expect(ServingScaler.formatNumber(245.0, countable: false), '245');
      expect(ServingScaler.formatNumber(10.4, countable: false), '10');
      expect(ServingScaler.formatNumber(9.96, countable: false), '10');
    });
    test('1..10 rounds to 1 decimal with German comma', () {
      expect(ServingScaler.formatNumber(2.5, countable: false), '2,5');
      expect(ServingScaler.formatNumber(2.0, countable: false), '2');
      expect(ServingScaler.formatNumber(1.25, countable: false), '1,3');
    });
    test('< 1 rounds to 2 decimals', () {
      expect(ServingScaler.formatNumber(0.25, countable: false), '0,25');
      expect(ServingScaler.formatNumber(1 / 3, countable: false), '0,33');
      expect(ServingScaler.formatNumber(0.5, countable: false), '0,5');
    });
  });

  group('formatNumber (countable → nearest half, fractions)', () {
    test('renders halves as fractions, never decimals', () {
      expect(ServingScaler.formatNumber(2.66, countable: true), '2 ½');
      expect(ServingScaler.formatNumber(0.5, countable: true), '½');
      expect(ServingScaler.formatNumber(3.0, countable: true), '3');
      expect(ServingScaler.formatNumber(2.24, countable: true), '2');
    });
    test('a tiny positive amount never becomes 0', () {
      expect(ServingScaler.formatNumber(0.2, countable: true), '½');
    });
  });

  group('scaledLine', () {
    const spaghetti =
        Ingredient(amount: 500, unit: 'g', name: 'Spaghetti', raw: '500 g Spaghetti');
    const egg = Ingredient(amount: 2, name: 'Ei(er)', raw: '2 Ei(er) (Größe M)');
    const garlic = Ingredient(
        amount: 2, amountMax: 3, unit: 'Zehen', name: 'Knoblauch', raw: '2-3 Zehen Knoblauch');
    const salt = Ingredient(name: 'Salz', raw: 'Salz, nach Belieben');

    test('factor 1 shows the original raw text', () {
      expect(ServingScaler.scaledLine(spaghetti, 1.0), '500 g Spaghetti');
      expect(ServingScaler.scaledLine(egg, 1.0), '2 Ei(er) (Größe M)');
    });

    test('scales amount and keeps unit and name', () {
      expect(ServingScaler.scaledLine(spaghetti, 0.49), '245 g Spaghetti');
      expect(ServingScaler.scaledLine(spaghetti, 2.0), '1000 g Spaghetti');
    });

    test('ranges scale both bounds and render an en-dash (§5)', () {
      expect(ServingScaler.scaledLine(garlic, 2.0), '4–6 Zehen Knoblauch');
      expect(ServingScaler.scaledLine(garlic, 0.5), '1–1,5 Zehen Knoblauch');
    });

    test('countable ingredients render half-fractions (2,66 Eier never happens)', () {
      expect(ServingScaler.scaledLine(egg, 1.33), '2 ½ Ei(er)');
    });

    test('amount-less ingredients show raw unchanged at any factor', () {
      expect(ServingScaler.scaledLine(salt, 3.0), 'Salz, nach Belieben');
    });
  });
}
