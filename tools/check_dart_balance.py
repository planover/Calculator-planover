"""粗粒度 Dart 语法自检：括号配平检查。

本机没有 Flutter/Dart SDK，无法跑 `dart analyze`，因此用一个"忽略字符串与注释"
的配平检查作为最低限度的冒烟测试 —— 能抓出漏写/多写大括号这类最常见的手误。
用法：python tools/check_dart_balance.py [app 目录]
"""

import os
import sys

PAIRS = {')': '(', '}': '{', ']': '['}
OPEN = '({['


def strip_and_check(src):
    """返回 (是否配平, 问题描述)。"""
    stack = []
    line = 1
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        if c == '\n':
            line += 1
            i += 1
            continue
        if src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue
        if src.startswith('/*', i):
            j = src.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        if c in ("'", '"'):
            quote = c
            # 三引号字符串（Dart 支持 ''' 与 """）
            if src[i:i + 3] in ("'''", '"""'):
                quote = src[i:i + 3]
                i += 3
            else:
                i += 1
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src.startswith(quote, i):
                    i += len(quote)
                    break
                if src[i] == '\n':
                    line += 1
                i += 1
            continue
        if c in OPEN:
            stack.append((c, line))
        elif c in PAIRS:
            if not stack:
                return False, '第 %d 行：多余的 %s' % (line, c)
            o, ol = stack.pop()
            if o != PAIRS[c]:
                return False, '第 %d 行：%s 与第 %d 行的 %s 不匹配' % (line, c, ol, o)
        i += 1
    if stack:
        o, ol = stack[-1]
        return False, '第 %d 行的 %s 未闭合' % (ol, o)
    return True, ''


def main(argv):
    root = argv[1] if len(argv) > 1 else 'app'
    bad = 0
    total = 0
    for dirpath, _, files in os.walk(root):
        for fn in sorted(files):
            if not fn.endswith('.dart'):
                continue
            total += 1
            path = os.path.join(dirpath, fn)
            with open(path, encoding='utf-8') as fh:
                src = fh.read()
            ok, msg = strip_and_check(src)
            if not ok:
                bad += 1
                print('[FAIL] %s -> %s' % (path, msg))
    print('检查 %d 个 .dart 文件，异常 %d 个' % (total, bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
