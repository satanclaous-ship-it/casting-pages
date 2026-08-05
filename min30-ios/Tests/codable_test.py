#!/usr/bin/env python3
"""저장 파일이 앞으로도 계속 읽히는지 지킨다.

Swift 의 합성된 디코더는 **기본값이 있어도 키를 요구한다.** 그래서 필드를 하나
추가하는 것만으로 예전 파일이 통째로 안 읽히게 된다. 그러면 로드가 빈 상태로
남고, 다음 저장이 그 빈 상태로 파일을 덮어쓴다 — 기록이 사라진다.

실제로 한 번 그렇게 잃었다 (`categoryConfirmed` 를 추가한 판).

그래서 저장되는 모든 타입은 직접 쓴 관대한 디코더를 가져야 하고, 모든 저장
프로퍼티가 거기서 값을 받아야 한다. 필수 키는 타입마다 아래에 명시한 것만
허용한다 — 그게 없으면 기록을 살릴 수 없는 것들이다.

    python3 min30-ios/Tests/codable_test.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "Min30", "Models.swift")
STORE = os.path.join(ROOT, "Min30", "Store.swift")

# 타입 -> 필수로 둬도 되는 키. 나머지는 전부 decodeIfPresent 여야 한다.
REQUIRED_OK = {
    "Entry": {"day", "slot"},      # 어느 자리 기록인지 모르면 살릴 수 없다
    "Idea": {"text"},              # 본문 없는 아이디어는 아이디어가 아니다
    "DayReview": set(),
    "Settings": set(),
}


def strip_comments(src):
    return re.sub(r"//[^\n]*", "", src)


def block_after(src, start):
    """start 위치의 여는 중괄호부터 짝이 맞는 닫는 중괄호까지."""
    i = src.index("{", start)
    depth, j = 0, i
    while j < len(src):
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                return src[i + 1 : j]
        j += 1
    return ""


def struct_body(src, name):
    m = re.search(r"\bstruct\s+%s\b[^{]*" % re.escape(name), src)
    if not m:
        sys.exit("Models.swift 에서 struct %s 를 못 찾음" % name)
    return block_after(src, m.end() - 1)


def stored_props(body):
    """저장 프로퍼티만.

    계산 프로퍼티(`var x: Int { ... }`)와, 그 안에 있는 지역 변수를 모두 뺀다.
    지역 변수를 빼려면 줄만 봐서는 안 되고 중괄호 깊이를 따라가야 한다 —
    `var span: (...) { var e = dayEnd ... }` 의 `e` 가 저장 프로퍼티로 잡혔었다.
    """
    out = []
    depth = 0
    for line in body.split("\n"):
        stripped = line.strip()
        if depth == 0 and "{" not in stripped:
            m = re.match(r"var\s+(\w+)\s*(?::\s*[^={]+)?(?:=|$)", stripped)
            if m:
                out.append(m.group(1))
        depth += stripped.count("{") - stripped.count("}")
    return out


def decoder_body(src, name):
    """struct 안이든 extension 안이든 그 타입의 init(from:) 본문."""
    for m in re.finditer(r"\binit\s*\(\s*from\s+decoder\s*:", src):
        # 이 init 을 감싸는 가장 가까운 struct/extension 선언을 찾는다
        head = src[: m.start()]
        owner = None
        for om in re.finditer(r"\b(?:struct|extension)\s+([\w.]+)", head):
            owner = om.group(1)
        if owner and owner.split(".")[-1] == name:
            return block_after(src, m.end())
    return None


def check_model(src, name, problems):
    body = struct_body(src, name)
    props = stored_props(body)
    dec = decoder_body(src, name)

    if dec is None:
        problems.append(
            "%s: 직접 쓴 init(from:) 이 없다 — 합성된 디코더는 예전 파일을 깬다" % name
        )
        return

    allowed_required = REQUIRED_OK.get(name, set())
    for p in props:
        assigned = re.search(r"\b%s\s*=" % re.escape(p), dec)
        if not assigned:
            problems.append('%s: "%s" 를 디코더에서 안 읽는다' % (name, p))
            continue
        line = dec[assigned.start() : dec.index("\n", assigned.start()) if "\n" in dec[assigned.start():] else len(dec)]
        if "decodeIfPresent" not in line and p not in allowed_required:
            problems.append(
                '%s: "%s" 가 필수 키다 — 이 키 없는 예전 파일은 통째로 안 읽힌다' % (name, p)
            )
    return props


def check_snapshot(problems):
    src = strip_comments(open(STORE, encoding="utf-8").read())
    body = struct_body(src, "Snapshot")
    for line in body.split("\n"):
        line = line.strip()
        m = re.match(r"var\s+(\w+)\s*:\s*(.+?)\s*$", line)
        if not m:
            continue
        name, typ = m.group(1), m.group(2).rstrip(",")
        if not typ.endswith("?"):
            problems.append(
                'Snapshot: "%s" 가 옵셔널이 아니다 — 키가 없으면 파일 전체가 안 읽힌다' % name
            )


def main():
    src = strip_comments(open(MODELS, encoding="utf-8").read())
    problems = []

    for name in ("Entry", "Idea", "DayReview", "Settings"):
        props = check_model(src, name, problems)
        if props:
            print("%-10s 저장 프로퍼티 %d개 확인" % (name, len(props)))

    check_snapshot(problems)
    print("Snapshot   전 필드 옵셔널 확인")

    if problems:
        print("\n예전 저장 파일을 깨뜨릴 수 있는 것:")
        for p in problems:
            print("  ✗ " + p)
        sys.exit(1)

    print("\n전부 통과 — 필드를 늘려도 예전 기록은 계속 읽힌다")


if __name__ == "__main__":
    main()
