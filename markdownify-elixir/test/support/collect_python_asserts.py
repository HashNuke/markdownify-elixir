#!/usr/bin/env python3
import ast
import json
import pathlib


CONSTANTS = {
    "ATX": "atx",
    "ATX_CLOSED": "atx_closed",
    "BACKSLASH": "backslash",
    "SPACES": "spaces",
    "UNDERSCORE": "_",
    "ASTERISK": "*",
    "LSTRIP": "lstrip",
    "RSTRIP": "rstrip",
    "STRIP": "strip",
    "STRIP_ONE": "strip_one",
}


def literal(node, env=None):
    env = env or {}
    if isinstance(node, ast.Name) and node.id in CONSTANTS:
        return CONSTANTS[node.id]
    if isinstance(node, ast.Name) and node.id in env:
        return env[node.id]
    if isinstance(node, ast.List):
        return [literal(elt, env) for elt in node.elts]
    if isinstance(node, ast.Tuple):
        return [literal(elt, env) for elt in node.elts]
    if isinstance(node, ast.Constant):
        return node.value
    return ast.literal_eval(node)


def call_case(node, env):
    if not isinstance(node, ast.Call):
        return None
    fn = node.func
    if isinstance(fn, ast.Name):
        name = fn.id
    elif isinstance(fn, ast.Attribute):
        name = fn.attr
    else:
        return None
    if name not in {"md", "markdownify"}:
        return None
    if len(node.args) != 1:
        return None

    try:
        html = literal(node.args[0], env)
        options = {kw.arg: literal(kw.value, env) for kw in node.keywords if kw.arg}
    except Exception:
        return None

    if not isinstance(html, str):
        return None

    return name, html, options


def collect(root):
    cases = []
    for path in sorted((root / "tests").glob("test_*.py")):
        if path.name == "test_custom_converter.py":
            # These assertions exercise Python subclass dispatch. The default
            # converter parity suite below covers the shared library API.
            continue
        tree = ast.parse(path.read_text(), filename=str(path))
        env = {}
        for stmt in tree.body:
            if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1 and isinstance(stmt.targets[0], ast.Name):
                try:
                    env[stmt.targets[0].id] = literal(stmt.value, env)
                except Exception:
                    pass

        for node in ast.walk(tree):
            if not isinstance(node, ast.Assert):
                continue
            test = node.test
            if not (
                isinstance(test, ast.Compare)
                and len(test.ops) == 1
                and isinstance(test.ops[0], ast.Eq)
                and len(test.comparators) == 1
            ):
                continue

            case = call_case(test.left, env)
            if case is None:
                continue
            try:
                expected = literal(test.comparators[0], env)
            except Exception:
                continue
            if not isinstance(expected, str):
                continue

            name, html, options = case
            cases.append(
                {
                    "file": str(path.relative_to(root)),
                    "function": name,
                    "line": node.lineno,
                    "html": html,
                    "options": options,
                    "expected": expected,
                }
            )
    return cases


if __name__ == "__main__":
    root = pathlib.Path(__file__).resolve().parents[3]
    print(json.dumps(collect(root), ensure_ascii=False))
