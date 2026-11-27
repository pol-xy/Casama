"""
Casama AI — Multinomial Naive Bayes task classifier (trainer + evaluator).

Implemented from scratch with the Python standard library only, so every
step of the algorithm is visible:

    P(class | words) ∝ P(class) · Π P(word | class)

Two independent classifiers are trained on the same task titles:
    * category  → diy | landlord | restock
    * urgency   → low | medium | urgent

Usage (from the repository root):
    python3 ai/naive_bayes/train_classifier.py

Outputs:
    assets/ai/task_classifier_model.json   ← model loaded by the Flutter app
    ai/results/naive_bayes_results.md      ← evaluation report (README uses it)
    ai/results/naive_bayes_results.json    ← same numbers, machine readable
"""

from __future__ import annotations

import csv
import json
import math
import random
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATASET = ROOT / "ai" / "data" / "tasks_dataset.csv"
MODEL_OUT = ROOT / "assets" / "ai" / "task_classifier_model.json"
RESULTS_DIR = ROOT / "ai" / "results"

SEED = 42
TEST_RATIO = 0.2
K_FOLDS = 5
ALPHA_GRID = [0.1, 0.25, 0.5, 1.0, 2.0]
CONFIDENCE_THRESHOLDS = [0.0, 0.5, 0.6, 0.7, 0.8, 0.9]
APP_THRESHOLD = 0.6  # must match NaiveBayesTaskClassifier.autoApplyThreshold

# Small English + Filipino stop-word list. Must match lib/ai/text_tokenizer.dart.
STOPWORDS = {
    "the", "a", "an", "in", "on", "of", "for", "to", "and", "is", "it", "our",
    "my", "at", "from", "with", "be", "are", "will", "not", "need", "needs",
    "sa", "ng", "ang", "na", "mga", "at", "ay", "si", "ni", "para", "po",
}

TOKEN_SPLIT = re.compile(r"[^a-z0-9ñ]+")


# --------------------------------------------------------------------------
# Feature extraction
# --------------------------------------------------------------------------
def tokenize(text: str) -> list[str]:
    """Lowercase → split on non-alphanumerics → drop stopwords → add bigrams."""
    words = [w for w in TOKEN_SPLIT.split(text.lower()) if w and w not in STOPWORDS]
    bigrams = [f"{a}_{b}" for a, b in zip(words, words[1:])]
    return words + bigrams


# --------------------------------------------------------------------------
# Multinomial Naive Bayes
# --------------------------------------------------------------------------
class MultinomialNaiveBayes:
    def __init__(self, alpha: float = 1.0):
        self.alpha = alpha  # Laplace / additive smoothing
        self.classes: list[str] = []
        self.log_prior: dict[str, float] = {}
        self.log_likelihood: dict[str, dict[str, float]] = {}
        self.log_unknown: dict[str, float] = {}
        self.vocab: set[str] = set()

    def fit(self, docs: list[list[str]], labels: list[str]) -> "MultinomialNaiveBayes":
        self.classes = sorted(set(labels))
        n_docs = len(docs)
        class_doc_count = Counter(labels)
        word_counts: dict[str, Counter] = defaultdict(Counter)
        for tokens, label in zip(docs, labels):
            word_counts[label].update(tokens)
            self.vocab.update(tokens)

        v = len(self.vocab)
        for c in self.classes:
            # Prior: P(c) = docs in c / all docs
            self.log_prior[c] = math.log(class_doc_count[c] / n_docs)
            total = sum(word_counts[c].values())
            denom = total + self.alpha * v
            # Likelihood with smoothing: P(w|c) = (count(w,c) + α) / (Σcount(c) + α|V|)
            self.log_likelihood[c] = {
                w: math.log((word_counts[c][w] + self.alpha) / denom) for w in self.vocab
            }
            # Unseen word in this class: (0 + α) / denom
            self.log_unknown[c] = math.log(self.alpha / denom)
        return self

    def log_scores(self, tokens: list[str]) -> dict[str, float]:
        scores = {}
        for c in self.classes:
            s = self.log_prior[c]
            for t in tokens:
                if t in self.vocab:  # words never seen in training are ignored
                    s += self.log_likelihood[c][t]
            scores[c] = s
        return scores

    def predict_proba(self, tokens: list[str]) -> dict[str, float]:
        """Softmax over log scores (log-sum-exp for numerical stability)."""
        scores = self.log_scores(tokens)
        m = max(scores.values())
        exp = {c: math.exp(s - m) for c, s in scores.items()}
        z = sum(exp.values())
        return {c: e / z for c, e in exp.items()}

    def predict(self, tokens: list[str]) -> str:
        scores = self.log_scores(tokens)
        return max(scores, key=scores.get)

    def to_json(self) -> dict:
        return {
            "alpha": self.alpha,
            "classes": self.classes,
            "logPrior": self.log_prior,
            "logLikelihood": {
                c: {w: round(lp, 6) for w, lp in sorted(d.items())}
                for c, d in self.log_likelihood.items()
            },
        }

    def top_words(self, c: str, n: int = 8) -> list[str]:
        """Most discriminative tokens: highest log P(w|c) − mean log P(w|other)."""
        others = [o for o in self.classes if o != c]
        def lift(w):
            return self.log_likelihood[c][w] - sum(self.log_likelihood[o][w] for o in others) / len(others)
        return sorted((w for w in self.vocab if "_" not in w), key=lift, reverse=True)[:n]


# --------------------------------------------------------------------------
# Evaluation helpers
# --------------------------------------------------------------------------
def stratified_split(rows, label_key, test_ratio, seed):
    rng = random.Random(seed)
    by_label = defaultdict(list)
    for r in rows:
        by_label[r[label_key]].append(r)
    train, test = [], []
    for label in sorted(by_label):
        group = by_label[label][:]
        rng.shuffle(group)
        k = max(1, round(len(group) * test_ratio))
        test += group[:k]
        train += group[k:]
    return train, test


def k_fold_indices(n, k, seed):
    idx = list(range(n))
    random.Random(seed).shuffle(idx)
    return [idx[i::k] for i in range(k)]


def metrics(y_true, y_pred, classes):
    cm = {t: {p: 0 for p in classes} for t in classes}
    for t, p in zip(y_true, y_pred):
        cm[t][p] += 1
    per_class = {}
    for c in classes:
        tp = cm[c][c]
        fp = sum(cm[t][c] for t in classes if t != c)
        fn = sum(cm[c][p] for p in classes if p != c)
        prec = tp / (tp + fp) if tp + fp else 0.0
        rec = tp / (tp + fn) if tp + fn else 0.0
        f1 = 2 * prec * rec / (prec + rec) if prec + rec else 0.0
        per_class[c] = {"precision": prec, "recall": rec, "f1": f1, "support": tp + fn}
    acc = sum(t == p for t, p in zip(y_true, y_pred)) / len(y_true)
    macro_f1 = sum(v["f1"] for v in per_class.values()) / len(classes)
    return {"accuracy": acc, "macro_f1": macro_f1, "per_class": per_class, "confusion": cm}


def cross_validate(rows, label_key, alpha):
    folds = k_fold_indices(len(rows), K_FOLDS, SEED)
    accs = []
    for i in range(K_FOLDS):
        test_idx = set(folds[i])
        tr = [r for j, r in enumerate(rows) if j not in test_idx]
        te = [r for j, r in enumerate(rows) if j in test_idx]
        m = MultinomialNaiveBayes(alpha).fit([tokenize(r["title"]) for r in tr], [r[label_key] for r in tr])
        accs.append(sum(m.predict(tokenize(r["title"])) == r[label_key] for r in te) / len(te))
    mean = sum(accs) / len(accs)
    std = math.sqrt(sum((a - mean) ** 2 for a in accs) / len(accs))
    return mean, std


def evaluate_task(rows, label_key):
    train, test = stratified_split(rows, label_key, TEST_RATIO, SEED)

    # 1) Choose α by 5-fold cross-validation on the TRAINING split only.
    cv = {a: cross_validate(train, label_key, a) for a in ALPHA_GRID}
    best_alpha = max(ALPHA_GRID, key=lambda a: (cv[a][0], -a))

    # 2) Fit on train, evaluate once on the held-out test split.
    model = MultinomialNaiveBayes(best_alpha).fit(
        [tokenize(r["title"]) for r in train], [r[label_key] for r in train]
    )
    y_true = [r[label_key] for r in test]
    y_pred = [model.predict(tokenize(r["title"])) for r in test]
    m = metrics(y_true, y_pred, model.classes)

    # Baseline: always predict the most frequent class of the training split.
    majority = Counter(r[label_key] for r in train).most_common(1)[0][0]
    baseline_acc = sum(t == majority for t in y_true) / len(y_true)

    # Selective prediction: how accurate is the model when it is confident?
    # The app only auto-fills a field when confidence >= APP_THRESHOLD.
    probas = [model.predict_proba(tokenize(r["title"])) for r in test]
    confidence = []
    for th in CONFIDENCE_THRESHOLDS:
        kept = [(t, max(pr, key=pr.get)) for t, pr in zip(y_true, probas) if max(pr.values()) >= th]
        confidence.append({
            "threshold": th,
            "coverage": len(kept) / len(y_true),
            "accuracy": (sum(t == p for t, p in kept) / len(kept)) if kept else None,
        })

    errors = [
        {"title": r["title"], "true": t, "pred": p}
        for r, t, p in zip(test, y_true, y_pred) if t != p
    ]

    # 3) Final model for the app is trained on ALL data with the chosen α.
    final = MultinomialNaiveBayes(best_alpha).fit(
        [tokenize(r["title"]) for r in rows], [r[label_key] for r in rows]
    )
    return {
        "train_size": len(train),
        "test_size": len(test),
        "cv": {str(a): {"mean": cv[a][0], "std": cv[a][1]} for a in ALPHA_GRID},
        "best_alpha": best_alpha,
        "test": m,
        "baseline_majority": {"class": majority, "accuracy": baseline_acc},
        "confidence": confidence,
        "errors": errors,
        "top_words": {c: final.top_words(c) for c in final.classes},
    }, final


# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------
def pct(x):
    return f"{x * 100:.1f}%"


def markdown_report(results, dataset_info):
    lines = ["# Naive Bayes Task Classifier — Evaluation Results", ""]
    lines.append(f"Generated by `ai/naive_bayes/train_classifier.py` (seed={SEED}).")
    lines.append("")
    lines.append(f"Dataset: **{dataset_info['n']} labeled task titles** "
                 f"(category: {dataset_info['category']}; urgency: {dataset_info['urgency']}).")
    lines.append("")
    for key, r in results.items():
        t = r["test"]
        classes = list(t["per_class"].keys())
        lines += [f"## {key.capitalize()} classifier", ""]
        lines.append(f"- Train / test split: {r['train_size']} / {r['test_size']} (stratified, 80/20)")
        lines.append(f"- Smoothing α chosen by {K_FOLDS}-fold CV on the training split: **{r['best_alpha']}**")
        lines.append(f"- **Test accuracy: {pct(t['accuracy'])}**  ·  Macro F1: {pct(t['macro_f1'])}")
        lines.append(f"- Majority-class baseline (`{r['baseline_majority']['class']}`): "
                     f"{pct(r['baseline_majority']['accuracy'])}")
        lines.append("")
        lines.append("| α | CV accuracy (mean ± std) |")
        lines.append("|---|---|")
        for a, v in r["cv"].items():
            lines.append(f"| {a} | {pct(v['mean'])} ± {pct(v['std'])} |")
        lines.append("")
        lines.append("| Class | Precision | Recall | F1 | Support |")
        lines.append("|---|---|---|---|---|")
        for c, v in t["per_class"].items():
            lines.append(f"| {c} | {pct(v['precision'])} | {pct(v['recall'])} | {pct(v['f1'])} | {v['support']} |")
        lines.append("")
        lines.append("Confusion matrix (rows = actual, columns = predicted):")
        lines.append("")
        lines.append("| actual \\ predicted | " + " | ".join(classes) + " |")
        lines.append("|---|" + "---|" * len(classes))
        for a in classes:
            lines.append(f"| **{a}** | " + " | ".join(str(t["confusion"][a][p]) for p in classes) + " |")
        lines.append("")
        lines.append(f"Confidence threshold analysis (the app auto-fills only at ≥ {APP_THRESHOLD}):")
        lines.append("")
        lines.append("| Min confidence | Coverage (share of test titles) | Accuracy on covered |")
        lines.append("|---|---|---|")
        for c in r["confidence"]:
            acc = pct(c["accuracy"]) if c["accuracy"] is not None else "—"
            lines.append(f"| {c['threshold']:.1f} | {pct(c['coverage'])} | {acc} |")
        lines.append("")
        lines.append("Most indicative words per class (final model):")
        lines.append("")
        for c, words in r["top_words"].items():
            lines.append(f"- **{c}**: " + ", ".join(f"`{w}`" for w in words))
        lines.append("")
        if r["errors"]:
            lines.append("Misclassified test examples:")
            lines.append("")
            lines.append("| Title | Actual | Predicted |")
            lines.append("|---|---|---|")
            for e in r["errors"]:
                lines.append(f"| {e['title']} | {e['true']} | {e['pred']} |")
            lines.append("")
    return "\n".join(lines)


def main():
    with DATASET.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    dataset_info = {
        "n": len(rows),
        "category": dict(sorted(Counter(r["category"] for r in rows).items())),
        "urgency": dict(sorted(Counter(r["urgency"] for r in rows).items())),
    }

    results, models = {}, {}
    for key in ("category", "urgency"):
        results[key], models[key] = evaluate_task(rows, key)

    MODEL_OUT.parent.mkdir(parents=True, exist_ok=True)
    MODEL_OUT.write_text(json.dumps({
        "name": "casama-task-classifier",
        "algorithm": "Multinomial Naive Bayes (unigram + bigram, Laplace smoothing)",
        "trainedOn": len(rows),
        "stopwords": sorted(STOPWORDS),
        "category": models["category"].to_json(),
        "urgency": models["urgency"].to_json(),
    }, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    (RESULTS_DIR / "naive_bayes_results.json").write_text(
        json.dumps({"dataset": dataset_info, **results}, indent=2, ensure_ascii=False), encoding="utf-8")
    (RESULTS_DIR / "naive_bayes_results.md").write_text(markdown_report(results, dataset_info), encoding="utf-8")

    for key, r in results.items():
        app = next(c for c in r["confidence"] if c["threshold"] == APP_THRESHOLD)
        print(f"{key:9s} test acc={pct(r['test']['accuracy'])}  macroF1={pct(r['test']['macro_f1'])}  "
              f"baseline={pct(r['baseline_majority']['accuracy'])}  alpha={r['best_alpha']}")
        print(f"{'':9s} at conf>={APP_THRESHOLD}: coverage={pct(app['coverage'])} acc={pct(app['accuracy'] or 0)}")
    print(f"model  → {MODEL_OUT.relative_to(ROOT)}")
    print(f"report → {(RESULTS_DIR / 'naive_bayes_results.md').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
