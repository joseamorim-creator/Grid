#!/usr/bin/env python3
"""Hook PreToolUse: bloqueia escritas com segredos aparentes ou Python com erro de sintaxe.

Recebe o JSON do tool call no stdin. Sai com código 2 para bloquear (a mensagem
em stderr volta para o Claude); 0 para liberar.
"""

import json
import re
import sys

SECRET_PATTERNS = [
    ("chave Google/Gemini", re.compile(r"AIza[0-9A-Za-z_\-]{35}")),
    ("chave AWS", re.compile(r"AKIA[0-9A-Z]{16}")),
    ("token GitHub", re.compile(r"gh[pousr]_[0-9A-Za-z]{36,}")),
    ("token Slack", re.compile(r"xox[baprs]-[0-9A-Za-z\-]{10,}")),
    ("chave privada", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("segredo atribuído", re.compile(
        r"""(?i)\b(?:api[_-]?key|secret|password|passwd|token)\b\s*[:=]\s*["'][^"'\s]{12,}["']""")),
]


def new_content(tool_input):
    if "content" in tool_input:
        return tool_input["content"]
    if "new_string" in tool_input:
        return tool_input["new_string"]
    edits = tool_input.get("edits") or []
    return "\n".join(e.get("new_string", "") for e in edits)


def main():
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0
    tool_input = payload.get("tool_input") or {}
    path = tool_input.get("file_path", "")
    text = new_content(tool_input)

    problems = [name for name, rx in SECRET_PATTERNS if rx.search(text)]
    if problems:
        print(f"Bloqueado: possível segredo em {path} ({', '.join(problems)}). "
              "Use variável de ambiente ou secret do Fury.", file=sys.stderr)
        return 2

    if path.endswith(".py") and "content" in tool_input:
        try:
            compile(text, path, "exec")
        except SyntaxError as e:
            print(f"Bloqueado: erro de sintaxe em {path}:{e.lineno}: {e.msg}", file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
