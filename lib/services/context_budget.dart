/// Estimates how many tokens the native conversation holds so the app can
/// start a fresh conversation before LiteRT-LM's context window overflows.
///
/// flutter_gemma's built-in trimming can't be relied on here: it counts only
/// model replies, never user prompts; it skips replies cut short by Stop or
/// the response cap; and on LiteRT-LM its history replay sends every past
/// turn as one user message.
class ContextBudget {
  ContextBudget({required this.maxTokens, required this.reservedForReply})
    : assert(reservedForReply < maxTokens);

  /// Size of the context window the engine was created with.
  final int maxTokens;

  /// Room kept free for the next reply.
  final int reservedForReply;

  /// Chat-template markers LiteRT-LM wraps around each turn.
  static const int _turnOverhead = 8;

  int _used = 0;

  int get used => _used;

  /// Longest prompt that fits in an otherwise empty conversation.
  int get maxPromptChars => (maxTokens - reservedForReply - _turnOverhead) * 4;

  /// Same ~4 chars/token heuristic LiteRT-LM's Android session uses for
  /// `sizeInTokens`, plus the turn markers.
  static int estimate(String text) => (text.length + 3) ~/ 4 + _turnOverhead;

  /// Whether [prompt] and a full-length reply fit on top of what is used.
  bool fits(String prompt) =>
      _used + estimate(prompt) + reservedForReply <= maxTokens;

  void add(String turn) => _used += estimate(turn);

  void reset() => _used = 0;
}
