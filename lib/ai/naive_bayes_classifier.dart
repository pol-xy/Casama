/// Casama AI — Multinomial Naive Bayes task classifier (on-device inference).
///
/// The model is trained offline by `ai/naive_bayes/train_classifier.py` and
/// exported to `assets/ai/task_classifier_model.json`. This file only does
/// inference, so it is pure Dart (no Flutter imports) and fully unit-testable.
///
///   score(c) = log P(c) + Σ log P(w | c)        for every known token w
///   P(c | title) = softmax(score)               (log-sum-exp for stability)
library;

import 'dart:math' as math;

import '../data/models.dart';

/// Tokenizer — MUST stay identical to `tokenize()` in train_classifier.py:
/// lowercase → split on non-alphanumerics → drop stopwords → add bigrams.
class TaskTitleTokenizer {
  final Set<String> stopwords;

  const TaskTitleTokenizer(this.stopwords);

  static final RegExp _split = RegExp(r'[^a-z0-9ñ]+');

  List<String> tokenize(String text) {
    final words = text
        .toLowerCase()
        .split(_split)
        .where((w) => w.isNotEmpty && !stopwords.contains(w))
        .toList();
    final bigrams = <String>[
      for (var i = 0; i + 1 < words.length; i++) '${words[i]}_${words[i + 1]}',
    ];
    return [...words, ...bigrams];
  }
}

/// Result of classifying a single field (category or urgency).
class ClassPrediction {
  final String label;
  final double confidence;
  final Map<String, double> probabilities;

  const ClassPrediction({
    required this.label,
    required this.confidence,
    required this.probabilities,
  });
}

/// One trained Multinomial NB model (one label set).
class MultinomialNaiveBayes {
  final List<String> classes;
  final Map<String, double> logPrior;
  final Map<String, Map<String, double>> logLikelihood;

  MultinomialNaiveBayes({
    required this.classes,
    required this.logPrior,
    required this.logLikelihood,
  });

  factory MultinomialNaiveBayes.fromJson(Map<String, dynamic> json) {
    final classes = (json['classes'] as List).cast<String>();
    final prior = (json['logPrior'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );
    final likelihood = (json['logLikelihood'] as Map<String, dynamic>).map(
      (c, words) => MapEntry(
        c,
        (words as Map<String, dynamic>).map(
          (w, v) => MapEntry(w, (v as num).toDouble()),
        ),
      ),
    );
    return MultinomialNaiveBayes(
      classes: classes,
      logPrior: prior,
      logLikelihood: likelihood,
    );
  }

  /// Every class shares one vocabulary, so checking the first one is enough.
  bool knows(String token) => logLikelihood[classes.first]!.containsKey(token);

  /// Returns null when none of the tokens were seen during training
  /// (the model would only be repeating the prior — not a real suggestion).
  ClassPrediction? predict(List<String> tokens) {
    final known = tokens.where(knows).toList();
    if (known.isEmpty) return null;

    final scores = <String, double>{};
    for (final c in classes) {
      var s = logPrior[c]!;
      final table = logLikelihood[c]!;
      for (final t in known) {
        s += table[t]!;
      }
      scores[c] = s;
    }

    final maxScore = scores.values.reduce(math.max);
    final exp = scores.map((c, s) => MapEntry(c, math.exp(s - maxScore)));
    final z = exp.values.fold<double>(0, (a, b) => a + b);
    final probs = exp.map((c, e) => MapEntry(c, e / z));

    final best = probs.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return ClassPrediction(
      label: best.key,
      confidence: best.value,
      probabilities: probs,
    );
  }
}

/// Suggested category + urgency for a maintenance task title.
class TaskSuggestion {
  final TaskCategory? category;
  final double categoryConfidence;
  final TaskUrgency? urgency;
  final double urgencyConfidence;

  const TaskSuggestion({
    this.category,
    this.categoryConfidence = 0,
    this.urgency,
    this.urgencyConfidence = 0,
  });

  bool get isEmpty => category == null && urgency == null;

  bool get shouldApplyCategory =>
      category != null &&
      categoryConfidence >= NaiveBayesTaskClassifier.autoApplyThreshold;

  bool get shouldApplyUrgency =>
      urgency != null &&
      urgencyConfidence >= NaiveBayesTaskClassifier.autoApplyThreshold;
}

/// Wraps both models (category + urgency) behind one `suggest()` call.
class NaiveBayesTaskClassifier {
  /// Only auto-fill a dropdown when the model is at least this confident.
  /// Chosen from the coverage/accuracy table in ai/results (APP_THRESHOLD).
  static const double autoApplyThreshold = 0.6;

  final TaskTitleTokenizer tokenizer;
  final MultinomialNaiveBayes categoryModel;
  final MultinomialNaiveBayes urgencyModel;
  final int trainedOn;

  NaiveBayesTaskClassifier({
    required this.tokenizer,
    required this.categoryModel,
    required this.urgencyModel,
    this.trainedOn = 0,
  });

  factory NaiveBayesTaskClassifier.fromJson(Map<String, dynamic> json) {
    return NaiveBayesTaskClassifier(
      tokenizer: TaskTitleTokenizer(
        (json['stopwords'] as List).cast<String>().toSet(),
      ),
      categoryModel: MultinomialNaiveBayes.fromJson(
        json['category'] as Map<String, dynamic>,
      ),
      urgencyModel: MultinomialNaiveBayes.fromJson(
        json['urgency'] as Map<String, dynamic>,
      ),
      trainedOn: json['trainedOn'] as int? ?? 0,
    );
  }

  TaskSuggestion suggest(String title) {
    final tokens = tokenizer.tokenize(title);
    final cat = categoryModel.predict(tokens);
    final urg = urgencyModel.predict(tokens);
    return TaskSuggestion(
      category: cat == null ? null : _category(cat.label),
      categoryConfidence: cat?.confidence ?? 0,
      urgency: urg == null ? null : _urgency(urg.label),
      urgencyConfidence: urg?.confidence ?? 0,
    );
  }

  static TaskCategory? _category(String label) {
    for (final c in TaskCategory.values) {
      if (c.name == label) return c;
    }
    return null;
  }

  static TaskUrgency? _urgency(String label) {
    for (final u in TaskUrgency.values) {
      if (u.name == label) return u;
    }
    return null;
  }
}
