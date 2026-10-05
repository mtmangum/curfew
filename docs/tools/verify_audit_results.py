#!/usr/bin/env python3
"""Check the retained A8 paired cohorts; reports are simulations, not novice rates."""
import json
import statistics
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'docs/qa/2026-10-05-audit-tooling'


def read(name):
    return json.loads((EVIDENCE / (name + '.json')).read_text())


def main():
    cohorts = {name: read(name) for name in ('level1', 'level2', 'level3-repeat', 'level3-variant', 'profile-level2')}
    sources = {r['source_signature'] for rows in cohorts.values() for r in rows}
    assert len(sources) == 1, 'Cohorts were built from different sources'
    repeated = cohorts['level3-repeat']
    keys = {(r['seed'], r['run']) for r in repeated}
    for key in sorted(keys):
        pair = [r for r in repeated if (r['seed'], r['run']) == key]
        assert len(pair) == 2 and pair[0] == pair[1], f'Replay mismatch: {key}'
        print(f'PASS exact full replay seed/run={key}: {pair[0]["outcome"]}, {pair[0]["seconds"]}s')
    variants = cohorts['level3-variant']
    assert {(r['seed'], r['run']) for r in variants} == keys
    for variant in variants:
        baseline = next(r for r in repeated if (r['seed'], r['run']) == (variant['seed'], variant['run']))
        assert baseline['initial_signature'] == variant['initial_signature']
        assert baseline['initial_conditions'] == variant['initial_conditions']
        assert baseline['destination_id'] == variant['destination_id']
        assert baseline['settings']['cop_sight'] != variant['settings']['cop_sight']
        print(f'PASS paired variant seed/run={variant["seed"]}/{variant["run"]}: matched initial state')
    for name in ('level1', 'level2'):
        rows = cohorts[name]
        for seed in {r['seed'] for r in rows}:
            assert len({r['initial_signature'] for r in rows if r['seed'] == seed}) == 1
        print(f'{name}: {len(rows)} runs; {len({r["destination_id"] for r in rows})} distinct destinations')
        for policy in dict.fromkeys(r['policy'] for r in rows):
            selected = [r for r in rows if r['policy'] == policy]
            wins = [r['seconds'] for r in selected if r['outcome'] == 'won']
            print(f'  {policy}: {dict(Counter(r["outcome"] for r in selected))}; median win {statistics.median(wins) if wins else "-"}s')
        assert all(r['outcome'] not in ('no_path', 'steering_failure', 'harness_clock_error') for r in rows)
    assert all(r['outcome'] == 'won' for r in cohorts['level1'])
    profile = cohorts['profile-level2']
    assert len(profile) == 3 and all(r['level'] == 2 and r['astar_path_length'] >= r['initial_home_distance'] for r in profile)
    for row in profile:
        played = next(r for r in cohorts['level2'] if r['seed'] == row['seed'])
        assert row['initial_signature'] == played['initial_signature']
        assert row['astar_path_length'] == played['astar_path_length']
    print('PASS profile mode honors level 2, JSON output, initial state and A* length')
    print('PASS all retained cohorts share source signature:', next(iter(sources)))
    print('These checks establish repeatable route-aware simulations, not beginner completion or retention.')


if __name__ == '__main__':
    main()
