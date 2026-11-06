#!/usr/bin/env python3
"""Run the tests through ttt, which provides the Lua runtime.

    scripts/test.py        unit tests in tests/unit

The unit tests are bundled with src/ into one plugin file and run headless with
`ttt --plugin`. ttt comes from TTT_BIN, or PATH.

Set PGTEST_URI (and PGTEST_PASSWORD) to also run a smoke test: the real plugin
connects to that database with psql from PATH and runs a query in a query tab.
"""

import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import build  # noqa: E402

ROOT = build.ROOT
TTT = os.environ.get("TTT_BIN") or shutil.which("ttt") or "ttt"
SIZE = "160x45"


def ttt(cfg: pathlib.Path, plugin: pathlib.Path, script: str, cwd: pathlib.Path) -> subprocess.CompletedProcess:
    env = dict(os.environ, TTT_CONFIG_DIR=str(cfg))
    return subprocess.run(
        [TTT, "--size", SIZE, "--plugin", str(plugin), "--exec", script],
        cwd=cwd,
        env=env,
        capture_output=True,
        text=True,
        timeout=120,
    )


def unit(tmp: pathlib.Path) -> bool:
    bundle = tmp / "unit" / "tests.lua"
    bundle.parent.mkdir()
    bundle.write_text(build.bundle((build.SRC, ROOT / "tests" / "unit"), "runner"), encoding="utf-8")
    run = ttt(tmp / "unit-config", bundle, 'exec "Postgres Tests: Run"; quit', tmp)
    results = bundle.parent / "results.txt"
    if not results.exists():
        print(run.stdout + run.stderr)
        print("test: the unit tests did not run")
        return False
    text = results.read_text(encoding="utf-8")
    print(text, end="")
    return run.returncode == 0 and " 0 failed" in text


def row_tabs(tmp: pathlib.Path) -> bool:
    bundle = tmp / "rows.lua"
    bundle.write_text(build.bundle((build.SRC, ROOT / "tests" / "fixtures"), "rows"), encoding="utf-8")
    actions = []
    states = []

    def capture(name: str, commands: list[str]) -> None:
        actions.extend(commands)
        path = tmp / (name + ".json")
        actions.append(f"debug {path}")
        actions.append(f"screenshot {path.with_suffix('.txt')}")
        states.append(path)

    capture("enter", ['exec "Rows: Table"', "click 60 9", "key enter"])
    capture("view", ['exec "Rows: Table"', "click 155 9"])
    capture("second-row", ['exec "Rows: Table"', "click 60 10", "key enter"])
    capture("close", ['exec "View: Close Tab"'])
    capture("reopen", ['exec "Rows: Table"', "click 155 10"])
    capture("refresh", ['exec "Rows: Replace"', 'exec "Rows: Table"', "click 60 9", "key enter"])
    capture("snapshot", ['exec "View: Previous Tab"', 'exec "View: Previous Tab"'])
    capture("query", ['exec "Rows: Query"', "click 60 19", "key enter"])
    actions.append("quit")
    run = ttt(tmp / "rows-config", bundle, "; ".join(actions), tmp)
    try:
        opened, viewed, second, closed, reopened, refreshed, snapshot, query = [
            dict(json.loads(path.read_text()), screen=path.with_suffix(".txt").read_text()) for path in states
        ]

        def active(state):
            return state["tabs"][state["active_tab"]]["path"]

        for state in (opened, viewed, second, reopened, refreshed, snapshot, query):
            assert state["focus"] == "editor", "row details should focus the editor"
            assert not state["overlay"], "row details should not open a dialog"
        assert len(opened["tabs"]) == 3 and "Alice" in opened["screen"]
        assert len(viewed["tabs"]) == 3 and active(viewed) == active(opened)
        assert len(second["tabs"]) == 4 and "Bob" in second["screen"]
        assert len(closed["tabs"]) == 3
        assert len(reopened["tabs"]) == 4 and "Bob" in reopened["screen"]
        assert len(refreshed["tabs"]) == 5 and "Carol" in refreshed["screen"]
        assert active(snapshot) == active(opened) and "Alice" in snapshot["screen"]
        assert "Query 1 · row 1" in query["screen"] and "END OF LONG VALUE" in query["screen"]
        assert "…" not in query["screen"], "row values should not be truncated"
        assert run.returncode == 0
    except (OSError, ValueError, AssertionError, KeyError) as err:
        print("FAIL row tabs: " + str(err))
        print(run.stdout + run.stderr)
        return False
    print("ok   row tabs: Enter, View, focus, reuse, close, refresh and query values")
    return True


def smoke(tmp: pathlib.Path, uri: str) -> bool:
    cfg = tmp / "smoke-config"
    state = cfg / "state" / "plugins"
    state.mkdir(parents=True)
    conn = {
        "name": "smoke",
        "uri": uri,
        "host": "",
        "port": "",
        "database": "",
        "user": "",
        "save_password": True,
        "password": os.environ.get("PGTEST_PASSWORD", ""),
    }
    (state / "postgres.json").write_text(json.dumps({"connections": [conn], "active": "smoke"}))
    shot = tmp / "smoke.txt"
    script = "; ".join(
        [
            'exec "Postgres: New Query"',
            'wait-for "F5 runs" timeout=20000',
            "click 60 7",
            "type select 40 + 2 as answer",
            "key f5",
            'wait-for "✓ 1 row" timeout=20000',
            f"screenshot {shot}",
            "quit",
        ]
    )
    run = ttt(cfg, ROOT / "init.lua", script, tmp)
    ok = run.returncode == 0 and shot.exists() and " 42 " in shot.read_text(encoding="utf-8")
    print(("ok   " if ok else "FAIL ") + "smoke: a query runs against " + uri)
    if not ok:
        print(run.stdout + run.stderr)
    return ok


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="ttt-postgres-test-") as name:
        tmp = pathlib.Path(name)
        ok = unit(tmp)
        ok = row_tabs(tmp) and ok
        uri = os.environ.get("PGTEST_URI")
        if uri:
            ok = smoke(tmp, uri) and ok
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
