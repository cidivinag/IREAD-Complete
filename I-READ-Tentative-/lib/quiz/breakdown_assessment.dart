import 'dart:math';

/// Helper: Tokenize by splitting on whitespace
List<String> tokens(String text) {
  return text.trim().toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
}

/// Very simple English stemmer
String _getStem(String word) {
  word = word.toLowerCase();
  // Special cases for common root families
  if (word.startsWith('beaut')) return 'beaut'; // beauty, beautiful, beautifully
  if (word.startsWith('run')) return 'run'; // run, running, runner
  if (word.startsWith('play')) return 'play'; // play, playing, player, playful
  if (word.startsWith('stud')) return 'stud'; // study, studies, studying, studied
  if (word.startsWith('happ')) return 'happ'; // happy, happiness, happily
  if (word.startsWith('try')) return 'try'; // try, tries, tried, trying
  if (word.startsWith('read')) return 'read'; // read, reading, reader
  if (word.startsWith('sing')) return 'sing'; // sing, singing, singer
  if (word.startsWith('teach')) return 'teach'; // teach, teacher, teaching
  if (word.startsWith('write')) return 'write'; // write, writer, writing
  if (word.startsWith('move')) return 'move'; // move, moving, movement
  if (word.startsWith('act')) return 'act'; // act, acting, actor, action
  // Add more as needed
  final suffixes = [
    'ation', 'ment', 'ness', 'ing', 'edly', 'ily', 'ied', 'ies', 'est', 'er', 'ed', 'es', 'ly', 's',
  ];
  for (final suf in suffixes) {
    if (word.endsWith(suf) && word.length > suf.length + 2) {
      return word.substring(0, word.length - suf.length);
    }
  }
  // General rule: if word ends with 'y' after a consonant, remove 'y'
  if (word.length > 3 && word.endsWith('y') && !'aeiou'.contains(word[word.length - 2])) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

/// Helper: Simple normalized Levenshtein similarity (0..1)
double wordSimilarity(String a, String b) {
  if (a == b) return 1.0;
  int dist = _levenshteinDistance(a, b);
  int maxLen = max(a.length, b.length);
  if (maxLen == 0) return 1.0;
  return 1.0 - (dist / maxLen);
}

/// Levenshtein distance (classic DP)
int _levenshteinDistance(String s, String t) {
  if (s == t) return 0;
  if (s.isEmpty) return t.length;
  if (t.isEmpty) return s.length;
  List<List<int>> dp = List.generate(
      s.length + 1, (_) => List.filled(t.length + 1, 0));
  for (int i = 0; i <= s.length; i++) dp[i][0] = i;
  for (int j = 0; j <= t.length; j++) dp[0][j] = j;
  for (int i = 1; i <= s.length; i++) {
    for (int j = 1; j <= t.length; j++) {
      int cost = s[i - 1] == t[j - 1] ? 0 : 1;
      dp[i][j] = [
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost
      ].reduce(min);
    }
  }
  return dp[s.length][t.length];
}


/// Custom word similarity for fuzzy WER
bool wordsAreSimilar(String a, String b, {double threshold = 0.6}) {
  if (a == b) return true;
  // Use stemmer for comparison
  if (_getStem(a) == _getStem(b)) return true;
  // For short words (<=5), allow 1 typo
  if (a.length <= 5 && b.length <= 5 && _levenshteinDistance(a, b) <= 1) return true;
  return wordSimilarity(a, b) > threshold;
}

/// Custom WER with fuzzy logic for accuracy
// Returns accuracy percentage (0..100, 1 decimal)
double calculateAccuracy(String expected, String actual) {
  final ref = tokens(expected);
  final hyp = tokens(actual);

  // Special handling for single-word case to avoid double-penalizing
  if (ref.length == 1 && hyp.length == 1) {
    String r = ref[0], h = hyp[0];
    if (r == h) return 100.0;
    double sim = wordSimilarity(r, h);
    if (sim > 0.85) {
      return double.parse((sim * 100).toStringAsFixed(1));
    }
    if (_getStem(r) == _getStem(h)) {
      // Partial credit for stem match
      return 75.0;
    }
    int minLen = r.length < h.length ? r.length : h.length;
    int maxLen = r.length > h.length ? r.length : h.length;
    if ((r.startsWith(h) || h.startsWith(r)) && (minLen / maxLen) >= 0.7) {
      // Proportional partial credit for strong prefix
      return double.parse(((minLen / maxLen) * 100).toStringAsFixed(1));
    }
    return 0.0;
  }

  int i = 0, j = 0;
  double totalError = 0.0;
  while (i < ref.length && j < hyp.length) {
    if (ref[i] == hyp[j]) {
      i++;
      j++;
      continue;
    }
    double sim = wordSimilarity(ref[i], hyp[j]);
    if (sim > 0.85) {
      totalError += 1 - sim;
      i++;
      j++;
      continue;
    }
    if (_getStem(ref[i]) == _getStem(hyp[j])) {
      totalError += 0.25; // partial penalty for stem match
      i++;
      j++;
      continue;
    }
    int minLen = ref[i].length < hyp[j].length ? ref[i].length : hyp[j].length;
    int maxLen = ref[i].length > hyp[j].length ? ref[i].length : hyp[j].length;
    if ((ref[i].startsWith(hyp[j]) || hyp[j].startsWith(ref[i])) && (minLen / maxLen) >= 0.7) {
      totalError += 1 - (minLen / maxLen); // proportional penalty
      i++;
      j++;
      continue;
    }
    if (ref[i].length > hyp[j].length) {
      totalError += 1.0;
      i++;
    } else {
      totalError += 0.5;
      j++;
    }
  }
  totalError += (ref.length - i) * 1.0;
  totalError += (hyp.length - j) * 0.5;
  double wer = ref.isEmpty ? 1.0 : totalError / ref.length;
  double acc = ((1 - wer) * 100).clamp(0, 100);
  return double.parse(acc.toStringAsFixed(1));
}

/// Completeness calculation as per spec
double calculateCompleteness(String expected, String actual) {
  final ref = tokens(expected);
  final hyp = tokens(actual);
  if (ref.length == 1 && hyp.length == 1) {
    // Single-word case
    String r = ref[0], h = hyp[0];
    if (r == h) return 100.0;
    int minLen = min(r.length, h.length);
    int maxLen = max(r.length, h.length);
    // Prefix match
    if (r.startsWith(h) || h.startsWith(r)) {
      return (minLen / maxLen * 100).clamp(0, 100);
    }
    // Stem match (using _getStem)
    if (_getStem(r) == _getStem(h)) {
      return 75.0;
    }
    // Shared prefix ≥3 chars
    int common = 0;
    for (int i = 0; i < minLen && r[i] == h[i]; i++) {
      common++;
    }
    if (common >= 3) {
      return min((common / minLen * 100), 75.0);
    }
    return 0.0;
  } else {
    // Multi-word case
    int matches = 0;
    for (final rw in ref) {
      bool found = false;
      for (final hw in hyp) {
        if (wordsAreSimilar(rw, hw)) {
          found = true;
          break;
        }
        if (_getStem(rw) == _getStem(hw)) {
          found = true;
          break;
        }
        // Prefix match only if at least 70% of ref word is covered
        int minLen = rw.length < hw.length ? rw.length : hw.length;
        int maxLen = rw.length;
        if ((rw.startsWith(hw) || hw.startsWith(rw)) && (minLen / maxLen) >= 0.7) {
          found = true;
          break;
        }
      }
      if (found) matches++;
    }
    double score = ref.isEmpty ? 0.0 : (matches / ref.length) * 100;
    return double.parse(score.toStringAsFixed(1));
  }
}
