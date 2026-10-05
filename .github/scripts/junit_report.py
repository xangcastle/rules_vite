"""Publishes the JUnit XML of every Bazel test in a workspace to a GitHub job.

usage: junit_report.py <workspace_dir> [--targets PATTERN ...] [--require //pkg:target=MIN_CASES ...]

Writes a per-target table (and the failing cases) to $GITHUB_STEP_SUMMARY,
emits an ::error annotation per failing case, and exits non-zero when a
--require'd target reports fewer real test cases than MIN_CASES (a report
Bazel synthesized for the whole target counts as zero).
"""

import argparse
import os
import pathlib
import subprocess
import sys
import xml.etree.ElementTree as ElementTree


def bazel(workspace, *args):
    output = subprocess.run(["bazel", *args], cwd=workspace, check=True, capture_output=True, text=True)
    return output.stdout


def test_labels(workspace, patterns):
    query = "tests(" + " + ".join(patterns) + ")"
    return {line.strip() for line in bazel(workspace, "query", query).splitlines() if line.strip()}


def target_label(testlogs, report):
    parts = report.relative_to(testlogs).parent.parts
    if parts and parts[-1].startswith("shard_"):
        parts = parts[:-1]
    return "//" + "/".join(parts[:-1]) + ":" + parts[-1]


def read_report(report, label):
    root = ElementTree.parse(report).getroot()
    cases = []
    for case in root.iter("testcase"):
        failure = case.find("failure")
        if failure is None:
            failure = case.find("error")
        cases.append({
            "name": case.get("name", ""),
            "file": case.get("classname", ""),
            "time": float(case.get("time") or 0),
            "skipped": case.find("skipped") is not None,
            "failure": None if failure is None else (failure.get("message") or failure.text or "").strip(),
        })
    synthesized = "Generated test.log" in ElementTree.tostring(root, encoding="unicode")
    return {"label": label, "cases": cases, "synthesized": synthesized}


def summary_markdown(workspace, results):
    lines = [f"### Test reports: `{workspace}`", "", "| target | cases | failed | skipped | time (s) | source |", "|---|---|---|---|---|---|"]
    for result in results:
        cases = result["cases"]
        failed = sum(1 for case in cases if case["failure"] is not None)
        skipped = sum(1 for case in cases if case["skipped"])
        seconds = sum(case["time"] for case in cases)
        kind = "Bazel placeholder (one entry per target)" if result["synthesized"] else "test runner (one entry per test)"
        lines.append(f"| `{result['label']}` | {len(cases)} | {failed} | {skipped} | {seconds:.2f} | {kind} |")
    failures = [(result["label"], case) for result in results for case in result["cases"] if case["failure"] is not None]
    if failures:
        lines += ["", "**Failing cases**", ""]
        for label, case in failures:
            first_line = case["failure"].splitlines()[0] if case["failure"] else "failed"
            lines.append(f"- `{label}` · `{case['file']}` · {case['name']}: {first_line}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("workspace")
    parser.add_argument("--targets", nargs="+", default=["//..."])
    parser.add_argument("--require", action="append", default=[])
    args = parser.parse_args()

    testlogs = pathlib.Path(bazel(args.workspace, "info", "bazel-testlogs").strip())
    wanted = test_labels(args.workspace, args.targets)
    reports = sorted(testlogs.rglob("test.xml")) if testlogs.exists() else []
    labelled = ((report, target_label(testlogs, report)) for report in reports)
    results = [read_report(report, label) for report, label in labelled if label in wanted]

    for result in results:
        for case in result["cases"]:
            if case["failure"] is not None:
                message = (case["failure"].splitlines() or ["failed"])[0].replace("%", "%25")
                print(f"::error title={result['label']} {case['name']}::{case['file']}: {message}")

    markdown = summary_markdown(args.workspace, results)
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as summary:
            summary.write(markdown)
    print(markdown)

    by_label = {result["label"]: result for result in results}
    missing = []
    for requirement in args.require:
        label, minimum = requirement.rsplit("=", 1)
        result = by_label.get(label)
        real_cases = 0 if result is None or result["synthesized"] else len(result["cases"])
        if real_cases < int(minimum):
            missing.append(f"{label}: {real_cases} per-case results, expected at least {minimum}")
    if missing:
        print("::error title=JUnit reports::" + "; ".join(missing))
        sys.exit(1)


main()
