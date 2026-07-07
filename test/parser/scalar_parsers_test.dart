import 'package:cookbook/src/parser/scalar_parsers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseIso8601DurationToMinutes', () {
    test('parses the real Chefkoch P0DT0H15M shape', () {
      expect(parseIso8601DurationToMinutes('P0DT0H15M'), 15);
      expect(parseIso8601DurationToMinutes('P0DT1H0M'), 60);
      expect(parseIso8601DurationToMinutes('P0DT1H40M'), 100);
    });
    test('parses plain schema.org shapes', () {
      expect(parseIso8601DurationToMinutes('PT15M'), 15);
      expect(parseIso8601DurationToMinutes('PT2H'), 120);
      expect(parseIso8601DurationToMinutes('P1DT2H30M'), 1590);
    });
    test('returns null for null, garbage, and zero durations', () {
      expect(parseIso8601DurationToMinutes(null), isNull);
      expect(parseIso8601DurationToMinutes(''), isNull);
      expect(parseIso8601DurationToMinutes('15 Minuten'), isNull);
      expect(parseIso8601DurationToMinutes('P0DT0H0M'), isNull);
    });
  });

  group('parseServings', () {
    test('parses the real "N Portionen" string shape', () {
      expect(parseServings('3 Portionen'), 3);
      expect(parseServings('12 Stück'), 12);
    });
    test('accepts plain numbers', () {
      expect(parseServings(4), 4);
      expect(parseServings(4.0), 4);
    });
    test('takes the first element of a list', () {
      expect(parseServings(['2 Portionen']), 2);
    });
    test('returns null when no leading integer exists', () {
      expect(parseServings('Portionen'), isNull);
      expect(parseServings(null), isNull);
      expect(parseServings(0), isNull);
      expect(parseServings(''), isNull);
    });
  });
}
