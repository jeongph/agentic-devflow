#!/usr/bin/env bash
# 플러그인 구조 검사 — 매니페스트·스킬 프론트매터·단계 파일 네 절·참조 경로·플레이스홀더
# 사용: scripts/check.sh   (실패 항목을 [FAIL]로 출력, 하나라도 있으면 exit 1)
set -u
cd "$(dirname "$0")/.."
fail=0
ok() { printf '[PASS] %s\n' "$1"; }
ng() { printf '[FAIL] %s\n' "$1"; fail=1; }

has_frontmatter() { # name·description·disable-model-invocation 프론트매터
  local f=$1
  [ -f "$f" ] || return 1
  [ "$(head -1 "$f")" = "---" ] || return 1
  sed -n '2,30p' "$f" | grep -qx -- '---' || return 1
  grep -q '^name: ' "$f" && grep -q '^description: ' "$f" && grep -q '^disable-model-invocation: true' "$f"
}
has_sections() { local f=$1; shift; [ -f "$f" ] || return 1; for h in "$@"; do grep -q "^$h" "$f" || return 1; done; }

# 1. 매니페스트
if python3 - <<'PY' 2>/dev/null
import json
d = json.load(open('.claude-plugin/plugin.json'))
missing = [k for k in ('name','version','description','author','license','dependencies') if k not in d]
assert not missing, missing
deps = [x['name'] if isinstance(x, dict) else x for x in d['dependencies']]
assert 'pr-review-toolkit' in deps
PY
then ok "plugin.json 필수 필드·pr-review-toolkit 의존성"; else ng "plugin.json 필수 필드·pr-review-toolkit 의존성"; fi

# 2. 스킬 프론트매터
for s in work review; do
  f="skills/$s/SKILL.md"
  if has_frontmatter "$f"; then ok "$f 프론트매터"; else ng "$f 프론트매터 (name/description/disable-model-invocation: true)"; fi
done

# 3. 단계 파일과 네 절
for n in 1-intake 2-scope 3-plan 4-implement 5-review 6-apply 7-ship; do
  f="skills/work/stages/$n.md"
  if has_sections "$f" '## 입력' '## 절차' '## 게이트' '## 출력'; then ok "$f"; else ng "$f (입력/절차/게이트/출력 네 절)"; fi
done

# 4. 참조 문서 존재
for r in base-resolution review-agents settings; do
  f="references/$r.md"
  if [ -f "$f" ]; then ok "$f"; else ng "$f 없음"; fi
done

# 5. 스킬·참조 문서가 언급하는 경로가 실재하는가
while IFS= read -r m; do
  [ -n "$m" ] || continue
  case "$m" in
    stages/*) p="skills/work/$m" ;;
    *) p="$m" ;;
  esac
  if [ -f "$p" ]; then ok "링크 $m"; else ng "링크 $m → $p 없음"; fi
done < <(grep -rhoE '(references|stages)/[A-Za-z0-9_.-]+\.md' skills references 2>/dev/null | sort -u)

# 6. 플레이스홀더
if grep -rnE '\b(TBD|TODO)\b' skills references README.md 2>/dev/null; then ng "플레이스홀더(TBD/TODO) 발견"; else ok "플레이스홀더 없음"; fi

exit $fail
