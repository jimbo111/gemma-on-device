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

  /// Longest ASCII prompt that fits in an otherwise empty conversation.
  /// Non-ASCII text costs more per character; check [fitsAlone] too.
  int get maxPromptChars => (maxTokens - reservedForReply - _turnOverhead) * 4;

  /// Conservative token estimate for [text] as one turn: ~4 ASCII chars per
  /// token, and every other UTF-16 unit as a full token, since CJK, Hangul
  /// and emoji often tokenize at 1-2 chars per token.
  static int estimate(String text) {
    var ascii = 0;
    var other = 0;
    for (final unit in text.codeUnits) {
      unit < 0x80 ? ascii++ : other++;
    }
    return (ascii + 3) ~/ 4 + other + _turnOverhead;
  }

  /// Whether [prompt] and a full-length reply fit on top of what is used.
  bool fits(String prompt) =>
      _used + estimate(prompt) + reservedForReply <= maxTokens;

  /// Whether [prompt] fits even in an empty conversation.
  bool fitsAlone(String prompt) =>
      estimate(prompt) + reservedForReply <= maxTokens;

  void addPrompt(String prompt) => _used += estimate(prompt);

  /// Charge a reply. [chunks] is the streamed chunk count, which tracks real
  /// tokens regardless of script; the text estimate covers multi-token chunks.
  void addReply(String reply, int chunks) {
    final byText = estimate(reply);
    final byChunks = chunks + _turnOverhead;
    _used += byText > byChunks ? byText : byChunks;
  }

  void reset() => _used = 0;
}
