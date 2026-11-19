#!/usr/bin/env python3
"""Deterministic, lossless importer for the question bank supplied in the brief."""
import argparse
import collections
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]


def parse(source):
    questions = []
    for original, section in [(True, source.split('25. ORIGINAL QUESTION BANK', 1)[1].split('26. ADDITIONAL QUESTION BANK', 1)[0]),
                              (False, source.split('26. ADDITIONAL QUESTION BANK', 1)[1].split('27. IMPORTANT QUESTION COUNT VALIDATION', 1)[0])]:
        if original:
            parts = re.split(r'\nROUND ([1-4])\n', section)
        else:
            parts = re.split(r'\nROUND ([1-4])\nADDITIONAL TRUTHS', section)
        for i in range(1, len(parts), 2):
            round_number, content = int(parts[i]), parts[i + 1]
            content = content.split('NUCLEAR ROUND' if original else 'ADDITIONAL NUCLEAR CHALLENGES')[0]
            truths, dares = re.split(r'(?:ROUND \d ADDITIONAL )?DARES:', content, maxsplit=1)
            for kind, block in [('truth', truths), ('dare', dares)]:
                for number, body in numbered(block):
                    title = None
                    if kind == 'dare' and round_number == 4:
                        title, body = body.split(':', 1)
                        body = body.strip()
                    questions.append(make_question(original, kind, round_number, number, title, body))
        nuclear = section.split('NUCLEAR ROUND' if original else 'ADDITIONAL NUCLEAR CHALLENGES', 1)[1]
        for number, body in numbered(nuclear):
            lines = body.split('\n', 1)
            title, text = lines[0].strip(), lines[1].strip()
            questions.append(make_question(original, 'nuclear', 5, number, title, text))
    return questions


def numbered(block):
    matches = list(re.finditer(r'^([0-9]+)\. (.+)$', block, re.M))
    for i, match in enumerate(matches):
        end = matches[i+1].start() if i+1 < len(matches) else len(block)
        body = block[match.start(2):end].strip()
        # Section dividers aren't part of question wording.
        body = re.split(r'\n=+', body)[0].strip()
        yield int(match.group(1)), body


def make_question(original, kind, round_number, number, title, text):
    timer = None
    if re.search(r'30.second|30 seconds', text): timer = 30
    if re.search(r'60.second|60 seconds|one.minute', text): timer = 60
    if 'two minutes' in text: timer = 120
    vote = None
    if title == 'THE ATTRACTION VOTE': vote = 'players'
    if title == 'THE SECRET CRUSH': vote = 'yesNo'
    if title == 'THE FINAL VERDICT': vote = 'verdict'
    if title in ['THE PERFECT FIRST DATE', 'THE UNIVERSITY SCANDAL']: vote = 'options'
    return dict(id=f"{'original' if original else 'additional'}_{kind}_r{round_number}_{number:03}",
                type=kind, round=round_number, intensity={1:6, 2:8, 3:9, 4:10, 5:10}[round_number],
                title=title, text=text, isOriginal=original,
                requiresOtherPlayers=kind != 'truth', timerSeconds=timer, voting=vote)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=pathlib.Path, default=ROOT / 'Documentation/SourceQuestionBank.txt')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    bank = parse(args.source.read_text())
    assert len(bank) == 197, len(bank)
    assert len({q['id'] for q in bank}) == 197
    assert sum(q['isOriginal'] for q in bank) == 95
    destination = ROOT / 'Resources/questions.json'
    if args.check:
        assert json.loads(destination.read_text()) == bank, 'Bundled content differs from supplied source'
    else:
        destination.write_text(json.dumps(bank, ensure_ascii=False, indent=2) + '\n')
    print(f"Validated {len(bank)} questions: 95 original + 102 additional; exact source wording preserved.")
    for original in [True, False]:
        print('Original' if original else 'Additional', dict(collections.Counter((q['round'], q['type']) for q in bank if q['isOriginal'] == original)))
