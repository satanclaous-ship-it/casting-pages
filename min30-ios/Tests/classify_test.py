#!/usr/bin/env python3
"""자동 분류 키워드 회귀 검사.

Swift 의 AutoTag.keywords 표를 소스에서 그대로 읽어 실제로 쓸 법한 문장에
돌린다. 키워드를 손볼 때 다른 걸 망가뜨리지 않았는지 여기서 걸린다.

분류는 저녁 리뷰에서 사람이 확인하므로 완벽할 필요는 없다. 다만 명백히 틀린
제안(통근이 회복, 업무가 회복)은 확인 자체를 번거롭게 만드므로 막아야 한다.

    python3 min30-ios/Tests/classify_test.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "Min30", "Models.swift")


def load_keywords():
    src = open(MODELS, encoding="utf-8").read()
    m = re.search(
        r"static let keywords: \[\(Category, \[String\]\)\] = \[(.*?)\n    \]", src, re.S
    )
    if not m:
        sys.exit("Models.swift 에서 keywords 표를 못 찾음 — 형태가 바뀌었나?")
    # 주석을 먼저 지운다. 주석 안의 따옴표(예: '"책" 단독은 금지')를 키워드로
    # 읽으면 지운 낱말이 살아 있는 것처럼 보여 오탐이 난다.
    body = re.sub(r"//[^\n]*", "", m.group(1))
    cats = re.findall(r"\(\.(\w+), \[(.*?)\]\)", body, re.S)
    return [(c, re.findall(r'"([^"]+)"', b)) for c, b in cats]


def load_fallback():
    src = open(MODELS, encoding="utf-8").read()
    m = re.search(r"static let fallback: Category = \.(\w+)", src)
    return m.group(1) if m else "maintain"


KW = load_keywords()
FALLBACK = load_fallback()


def norm(s):
    return s.lower().replace(" ", "").strip()


def classify(text):
    """Swift 의 AutoTag.classify 와 같은 규칙 — 표 순서대로 첫 매칭."""
    n = norm(text)
    if not n:
        return FALLBACK, None
    for cat, words in KW:
        for w in words:
            if w in n:
                return cat, w
    return FALLBACK, None


# (문장, 기대 분류) — 실제로 입력할 법한 것들
CASES = [
    # 이동·통근은 회복이 아니다. 쉬는 게 아니라 치러야 하는 비용이다.
    ("사무실 이동", "maintain"),
    ("출근길", "maintain"),
    ("퇴근", "maintain"),
    ("운전해서 미팅 장소로", "maintain"),
    # 성과를 만드는 일
    ("온보딩 화면 작업", "leverage"),
    ("앱스토어 심사 대응", "leverage"),
    ("버그 수정", "leverage"),
    ("코드 리뷰", "leverage"),
    ("기획서 초안", "leverage"),
    ("디자인 시안 검토", "leverage"),
    ("배포 준비", "leverage"),
    ("영상 편집", "leverage"),
    # 해야 하지만 성과는 아닌 것
    ("팀 회의 준비", "maintain"),
    ("이메일 확인", "maintain"),
    ("고객 문의 응대", "maintain"),
    ("슬랙 답장", "maintain"),
    ("주간 계획 세우기", "maintain"),
    # 1인 개발자에게 투자 유치는 잡무가 아니라 성과를 만드는 일이다
    ("투자자 미팅", "leverage"),
    # 배움 — 플랫폼 이름이 섞여도 행동이 이겨야 한다
    ("논문 읽기", "learn"),
    ("유튜브 강의 시청", "learn"),
    ("SwiftUI 문서 정독", "learn"),
    ("컨퍼런스 참석", "learn"),
    # 낭비 — 플랫폼 이름만 덩그러니
    ("유튜브 알고리즘", "waste"),
    ("인스타 스크롤", "waste"),
    ("둠스크롤", "waste"),
    ("넷플릭스", "waste"),
    # 의도한 회복
    ("점심 식사", "recover"),
    ("산책", "recover"),
    ("헬스장", "recover"),
    ("운동 후 샤워", "recover"),
    ("낮잠", "recover"),
    ("가족과 통화", "recover"),
    ("친구랑 저녁", "recover"),
]


def main():
    print(f"검사 순서: {' → '.join(c for c, _ in KW)}")
    print(f"매칭 없을 때: {FALLBACK}\n")

    wrong = []
    for text, want in CASES:
        got, word = classify(text)
        ok = got == want
        if not ok:
            wrong.append((text, want, got, word))
        print(
            "%s %-22s %-10s → %-10s %s"
            % ("  " if ok else "✗ ", text, want, got, f"({word})" if word else "(매칭 없음)")
        )

    print(f"\n{len(CASES) - len(wrong)}/{len(CASES)} 통과")

    if wrong:
        print("\n틀린 것:")
        for text, want, got, word in wrong:
            if word:
                print(f'  "{text}" → {got} (기대 {want}) · "{word}" 에 걸림')
            else:
                print(f'  "{text}" → {got} (기대 {want}) · 아무 키워드도 안 걸림')
        sys.exit(1)

    print("전부 통과")


if __name__ == "__main__":
    main()
