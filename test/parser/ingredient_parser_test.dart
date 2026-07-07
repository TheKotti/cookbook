import 'package:cookbook/src/models/recipe.dart';
import 'package:cookbook/src/parser/ingredient_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Matcher parsed({double? amount, double? amountMax, String? unit, required String name}) =>
      isA<Ingredient>()
          .having((i) => i.amount, 'amount', amount)
          .having((i) => i.amountMax, 'amountMax', amountMax)
          .having((i) => i.unit, 'unit', unit)
          .having((i) => i.name, 'name', name);

  test('simple amount + unit + name', () {
    expect(parseIngredient('500 g Spaghetti'), parsed(amount: 500, unit: 'g', name: 'Spaghetti'));
    expect(parseIngredient('3 EL Olivenöl'), parsed(amount: 3, unit: 'EL', name: 'Olivenöl'));
  });

  test('dot and comma decimals', () {
    expect(parseIngredient('0.5 Liter Milch'), parsed(amount: 0.5, unit: 'Liter', name: 'Milch'));
    expect(parseIngredient('0,5 l Sahne'), parsed(amount: 0.5, unit: 'l', name: 'Sahne'));
  });

  test('unicode and ascii fractions', () {
    expect(parseIngredient('½ Ei'), parsed(amount: 0.5, name: 'Ei'));
    expect(parseIngredient('1/2 Zitrone'), parsed(amount: 0.5, name: 'Zitrone'));
    expect(parseIngredient('1 ½ TL Salz'), parsed(amount: 1.5, unit: 'TL', name: 'Salz'));
  });

  test('ranges scale into amount/amountMax', () {
    expect(parseIngredient('2-3 Zehen Knoblauch'),
        parsed(amount: 2, amountMax: 3, unit: 'Zehen', name: 'Knoblauch'));
    expect(parseIngredient('2–3 EL Zucker'),
        parsed(amount: 2, amountMax: 3, unit: 'EL', name: 'Zucker'));
  });

  test('bare count with no unit', () {
    expect(parseIngredient('2  Ei(er) (Größe M)'), parsed(amount: 2, name: 'Ei(er)'));
    expect(parseIngredient('1  Zitrone(n), Saft davon'), parsed(amount: 1, name: 'Zitrone(n)'));
  });

  test('trailing parentheticals and comma qualifiers are cut from name, kept in raw', () {
    final pancetta = parseIngredient('100 g Pancetta (oder Guanciale, , alternativ Bacon)');
    expect(pancetta, parsed(amount: 100, unit: 'g', name: 'Pancetta'));
    expect(pancetta.raw, '100 g Pancetta (oder Guanciale, , alternativ Bacon)');
    expect(parseIngredient('1 Dose Tomaten, geschälte (800 g)'),
        parsed(amount: 1, unit: 'Dose', name: 'Tomaten'));
    expect(
        parseIngredient(
            '1 EL Rosmarin (getrocknet (frische Nadeln schmecken natürlich intensiver))'),
        parsed(amount: 1, unit: 'EL', name: 'Rosmarin'));
  });

  test('amount-less items keep null amount and clean name', () {
    expect(parseIngredient('  Salz und Pfeffer'), parsed(name: 'Salz und Pfeffer'));
    expect(parseIngredient(' etwas Chilipulver'), parsed(name: 'Chilipulver'));
    expect(parseIngredient(' etwas Rotwein (50–100 ml)'), parsed(name: 'Rotwein'));
    expect(parseIngredient('Salz, nach Belieben'), parsed(name: 'Salz'));
  });

  test('non-unit token after amount stays in name', () {
    expect(parseIngredient('10 m.-große Kartoffeln, festkochende'),
        parsed(amount: 10, name: 'm.-große Kartoffeln'));
  });

  test('raw is always the collapsed trimmed original and nothing is ever dropped', () {
    final weird = parseIngredient('   ');
    expect(weird.raw, '');
    expect(weird.name, '');
    final salz = parseIngredient('  Salz');
    expect(salz.raw, 'Salz');
  });
}
