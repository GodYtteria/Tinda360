import argparse
import json
import random
import re
import torch
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).parent
QUERIES_DIRECTORY = HERE / 'queries'
NOVEL_CASES_PATH = HERE / 'novel_eval.txt'
NO_TOOL_CLASS = 'no_tool'
REPLY_SEPARATOR = '||'
CHARACTER_NGRAM_SIZES = (3, 4)
MINIMUM_FEATURE_COUNT = 2
LOGISTIC_L2 = 1e-5
LOGISTIC_EPOCHS = 300
LOGISTIC_LEARNING_RATE = 0.05
EXPORT_WEIGHT_THRESHOLD = 0.0
FOLD_COUNT = 5
WORD_PATTERN = re.compile(r'[a-zñ0-9]+')


def tokenize(text):
    return WORD_PATTERN.findall(text.lower())


def extract_features(text):
    words = tokenize(text)
    features = [f'w:{word}' for word in words]
    features += [f'b:{first}_{second}' for first, second in zip(words, words[1:])]
    for word in words:
        padded = f'^{word}$'
        for size in CHARACTER_NGRAM_SIZES:
            features += [f'c:{padded[index:index + size]}' for index in range(len(padded) - size + 1)]
    return features


def load_labeled_queries():
    examples = []
    for path in sorted(QUERIES_DIRECTORY.glob('*.txt')):
        label = NO_TOOL_CLASS if path.stem == NO_TOOL_CLASS else path.stem
        for line in path.read_text(encoding='utf-8').splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith('@'):
                continue
            examples.append((stripped.split(REPLY_SEPARATOR)[0].strip(), label))
    return examples


def load_novel_cases():
    cases = []
    for line in NOVEL_CASES_PATH.read_text(encoding='utf-8').splitlines():
        if line.strip():
            query, tool, _ = line.split('|')
            cases.append((query, tool))
    return cases


class LogisticClassifier:
    def __init__(self, l2=LOGISTIC_L2, epochs=LOGISTIC_EPOCHS, learning_rate=LOGISTIC_LEARNING_RATE):
        self.l2 = l2
        self.epochs = epochs
        self.learning_rate = learning_rate
        self.classes = []
        self.vocabulary = {}
        self.weights = None
        self.bias = None

    def _vectorize(self, texts):
        matrix = torch.zeros(len(texts), len(self.vocabulary))
        for row, text in enumerate(texts):
            for feature in set(extract_features(text)):
                column = self.vocabulary.get(feature)
                if column is not None:
                    matrix[row, column] = 1.0
        return matrix / matrix.sum(1, keepdim=True).clamp(min=1) ** 0.5

    def fit(self, examples):
        document_frequency = Counter()
        for text, _ in examples:
            document_frequency.update(set(extract_features(text)))
        kept = sorted(feature for feature, count in document_frequency.items() if count >= MINIMUM_FEATURE_COUNT)
        self.vocabulary = {feature: index for index, feature in enumerate(kept)}
        self.classes = sorted({label for _, label in examples})
        matrix = self._vectorize([text for text, _ in examples])
        targets = torch.tensor([self.classes.index(label) for _, label in examples])
        weights = torch.zeros(len(self.vocabulary), len(self.classes), requires_grad=True)
        bias = torch.zeros(len(self.classes), requires_grad=True)
        optimizer = torch.optim.Adam([weights, bias], lr=self.learning_rate)
        for _ in range(self.epochs):
            optimizer.zero_grad()
            loss = torch.nn.functional.cross_entropy(matrix @ weights + bias, targets)
            loss = loss + self.l2 * (weights ** 2).sum()
            loss.backward()
            optimizer.step()
        self.weights = weights.detach()
        self.bias = bias.detach()
        return self

    def predict(self, text):
        probabilities = torch.softmax(self._vectorize([text]) @ self.weights + self.bias, dim=1)[0]
        best = int(probabilities.argmax())
        return self.classes[best], float(probabilities[best])

    def export(self):
        threshold = EXPORT_WEIGHT_THRESHOLD
        features = {}
        for feature, column in self.vocabulary.items():
            column_weights = self.weights[column]
            if float(column_weights.abs().max()) >= threshold:
                features[feature] = [round(float(value), 3) for value in column_weights]
        return {
            'classes': self.classes,
            'bias': [round(float(value), 4) for value in self.bias],
            'normalization_power': 0.5,
            'features': features,
        }


def cross_validate(examples):
    shuffled = examples[:]
    random.Random(7).shuffle(shuffled)
    correct = 0
    mistakes = defaultdict(list)
    for fold in range(FOLD_COUNT):
        held_out = shuffled[fold::FOLD_COUNT]
        training = [item for index, item in enumerate(shuffled) if index % FOLD_COUNT != fold]
        model = LogisticClassifier().fit(training)
        for text, label in held_out:
            predicted, _ = model.predict(text)
            if predicted == label:
                correct += 1
            else:
                mistakes[label].append((text, predicted))
    return correct / len(shuffled), mistakes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--export', default='')
    arguments = parser.parse_args()
    examples = load_labeled_queries()
    novel = load_novel_cases()
    novel_texts = {text for text, _ in novel}
    training = [item for item in examples if item[0] not in novel_texts]
    accuracy, mistakes = cross_validate(training)
    print(f'5-fold cross-validation: {accuracy:.1%} on {len(training)} queries')
    model = LogisticClassifier().fit(training)
    hits = sum(model.predict(text)[0] == tool for text, tool in novel)
    print(f'held-out novel set: {hits}/{len(novel)}')
    for label, wrong in sorted(mistakes.items(), key=lambda item: -len(item[1]))[:6]:
        print(f'  {label}: {len(wrong)} wrong, e.g. {wrong[0]}')
    if arguments.export:
        final_model = LogisticClassifier().fit(examples)
        Path(arguments.export).write_text(json.dumps(final_model.export(), ensure_ascii=False), encoding='utf-8')
        print(f'exported {len(final_model.export()['features'])} features to {arguments.export}')


if __name__ == '__main__':
    main()
