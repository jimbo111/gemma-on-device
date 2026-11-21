import 'package:flutter_test/flutter_test.dart';
import 'package:on_device_ai/services/context_budget.dart';

void main() {
  test('estimate rounds chars up to tokens and adds turn overhead', () {
    expect(ContextBudget.estimate(''), 8);
    expect(ContextBudget.estimate('abcd'), 9);
    expect(ContextBudget.estimate('abcde'), 10);
  });

  test('fits reserves room for a full reply', () {
    final budget = ContextBudget(maxTokens: 100, reservedForReply: 50);
    expect(budget.fits('a' * 160), isTrue); // 40 + 8 + 50 = 98
    expect(budget.fits('a' * 180), isFalse); // 45 + 8 + 50 = 103
  });

  test('history accumulates until reset', () {
    final budget = ContextBudget(maxTokens: 100, reservedForReply: 50);
    budget.add('a' * 120); // 38
    expect(budget.fits('hi'), isTrue); // 38 + 9 + 50 = 97
    budget.add('a' * 40); // 18
    expect(budget.fits('hi'), isFalse);
    budget.reset();
    expect(budget.used, 0);
    expect(budget.fits('hi'), isTrue);
  });

  test('maxPromptChars always fits in an empty conversation', () {
    final budget = ContextBudget(maxTokens: 2048, reservedForReply: 576);
    expect(budget.fits('a' * budget.maxPromptChars), isTrue);
    expect(budget.fits('a' * (budget.maxPromptChars + 4)), isFalse);
  });
}
