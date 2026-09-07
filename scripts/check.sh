#!/usr/bin/env bash
# 플러그인 구조 검사.
# 사용: scripts/check.sh   → 항목별 [PASS]/[FAIL] 출력, 하나라도 FAIL이면 exit 1
#
# 이 검사는 "문서에 이 구조·문장이 있는가"를 보는 회귀 앵커다. 런타임에서 Claude가 실제로
# 게이트에서 멈추는지, Agent 호출에 model이 들어가는지는 보증하지 못한다. 행동 검증은
# 샌드박스 드라이런(스펙 §9)으로 한다. check.sh 자체의 검출력은 scripts/check-selftest.sh가 본다.
set -uo pipefail
cd "$(dirname "$0")/.." || { echo "[FAIL] 레포 루트로 이동 실패" >&2; exit 2; }
fail=0
ok() { printf '[PASS] %s\n' "$1"; }
ng() { printf '[FAIL] %s\n' "$1"; fail=1; }

SKILLS="work review"
STAGE_DIR=skills/work/stages
REFS="preflight base-resolution review-agents settings"

frontmatter() { awk 'NR==1 && $0!="---"{exit} NR==1{next} /^---[[:space:]]*$/{exit} {print}' "$1"; }
fm_closed()   { awk 'NR>1 && /^---[[:space:]]*$/{f=1; exit} END{exit !f}' "$1"; }
headings()    { awk '/^[[:space:]]*```/{f=!f; next} !f && /^## /{print}' "$1"; }

# 1. 매니페스트 — 실패 원인을 그대로 출력한다
pname=""
if ! command -v python3 >/dev/null 2>&1; then
  ng "python3 없음 — 매니페스트 검사를 실행할 수 없음"
else
  err=$(python3 - <<'PY' 2>&1
import json, sys
try:
    d = json.load(open('.claude-plugin/plugin.json'))
except Exception as e:
    sys.exit(f'plugin.json 파싱 실패: {e}')
missing = [k for k in ('name', 'version', 'description', 'author', 'license', 'dependencies') if k not in d]
if missing:
    sys.exit(f'필수 필드 누락: {missing}')
try:
    deps = [x['name'] if isinstance(x, dict) else x for x in d['dependencies']]
except Exception as e:
    sys.exit(f'dependencies 형식 오류: {e}')
if 'pr-review-toolkit' not in deps:
    sys.exit(f'pr-review-toolkit 의존성 없음 (현재: {deps})')
print(d['name'])
PY
  )
  rc=$?
  if [ "$rc" -eq 0 ]; then pname=$err; ok "plugin.json 필수 필드·pr-review-toolkit 의존성"; else ng "plugin.json — $err"; fi
fi

# 2. plugin.json name ↔ 문서의 슬래시 커맨드 접두사 (디렉토리명은 클론 위치에 따라 달라 기준으로 삼지 않는다)
if [ -n "$pname" ]; then
  badpfx=$(grep -rhoE '/[a-z0-9-]+:[a-z0-9-]+' skills references README.md 2>/dev/null | grep -E ':(work|review)$' | grep -v "^/$pname:" | sort -u)
  if [ -z "$badpfx" ]; then ok "plugin.json name($pname) ↔ 슬래시 커맨드 접두사"; else ng "슬래시 커맨드 접두사 불일치: $(echo $badpfx) (기대: /$pname:…)"; fi
fi

# 3. 스킬 프론트매터 — 블록 안에서만 보고, 닫는 ---와 name↔디렉토리 일치까지
for s in $SKILLS; do
  f="skills/$s/SKILL.md"
  if [ ! -f "$f" ]; then ng "$f 없음"; continue; fi
  miss=""
  fm_closed "$f" || miss=" 닫는 --- 없음"
  fm=$(frontmatter "$f")
  [ -n "$fm" ] || miss="$miss 프론트매터 블록 없음"
  for k in name description; do printf '%s\n' "$fm" | grep -q "^$k:" || miss="$miss $k"; done
  printf '%s\n' "$fm" | grep -qx 'disable-model-invocation: true' || miss="$miss disable-model-invocation!=true"
  nm=$(printf '%s\n' "$fm" | sed -nE 's/^name:[[:space:]]*"?([A-Za-z0-9_-]+)"?[[:space:]]*$/\1/p')
  [ "$nm" = "$s" ] || miss="$miss name($nm)!=디렉토리($s)"
  if [ -z "$miss" ]; then ok "$f 프론트매터"; else ng "$f 프론트매터 —$miss"; fi
done

# 4. 단계 파일 — 파일시스템에서 열거, 네 절이 코드펜스 밖에 정확히 순서대로, SKILL.md 목록과 일치
stage_files=$(find "$STAGE_DIR" -name '[0-9]*.md' 2>/dev/null | sort)
n_stages=$(printf '%s\n' "$stage_files" | grep -c . || true)
[ "$n_stages" -ge 7 ] || ng "$STAGE_DIR 단계 파일 $n_stages개 (7개 이상 기대)"
for f in $stage_files; do
  got=$(headings "$f" | tr '\n' '|')
  if [ "$got" = "## 입력|## 절차|## 게이트|## 출력|" ]; then ok "$f 네 절"; else ng "$f 네 절 (코드펜스 밖에 입력/절차/게이트/출력 순서대로 하나씩) — 실제: ${got:-없음}"; fi
done
if [ -f skills/work/SKILL.md ]; then
  listed=$(grep -oE 'stages/[0-9][A-Za-z0-9_-]*\.md' skills/work/SKILL.md | sort -u)
  actual=$(printf '%s\n' $stage_files | sed "s#^$STAGE_DIR/#stages/#" | sort -u)
  if [ "$listed" = "$actual" ]; then ok "work/SKILL.md 단계 목록 ↔ $STAGE_DIR 일치"; else ng "work/SKILL.md 단계 목록 ↔ $STAGE_DIR 불일치 — 목록: $(echo $listed) / 실제: $(echo $actual)"; fi
fi

# 5. 참조 문서 존재
for r in $REFS; do f="references/$r.md"; if [ -f "$f" ]; then ok "$f"; else ng "$f 없음"; fi; done

# 6. 링크 — 런타임 해석 기준으로 실재하는가
#    SKILL.md: `${CLAUDE_PLUGIN_ROOT}/…`는 플러그인 루트, 그 외 상대 경로는 skills/<name>/ (런타임 base directory) 기준
#    references·stages·README: 플러그인 루트 기준 (SKILL.md가 앵커를 제공한다)
n_links=0
check_link() { n_links=$((n_links + 1)); if [ -f "$2" ]; then ok "링크 $3: $1"; else ng "링크 $3: $1 → $2 없음"; fi; }
for s in $SKILLS; do
  f="skills/$s/SKILL.md"; [ -f "$f" ] || continue
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    case "$m" in
      '${CLAUDE_PLUGIN_ROOT}/'*) check_link "$m" "${m#\$\{CLAUDE_PLUGIN_ROOT\}/}" "$f" ;;
      *) check_link "$m" "skills/$s/$m" "$f" ;;
    esac
  done < <(grep -oE '(\$\{CLAUDE_PLUGIN_ROOT\}/)?(skills|references|stages)(/[A-Za-z0-9_.-]+)+\.md' "$f" | sort -u)
done
while IFS= read -r m; do
  [ -n "$m" ] || continue
  case "$m" in
    docs/history/*) continue ;;   # 사용자 레포의 파일. 이 레포에 없는 게 정상
    *) check_link "$m" "$m" "본문" ;;
  esac
done < <(grep -rhoE '(skills|references|stages|docs)(/[A-Za-z0-9_.-]+)+\.md' references "$STAGE_DIR" README.md 2>/dev/null | sort -u)
[ "$n_links" -ge 15 ] || ng "링크 수집 $n_links건 — 참조 표기가 바뀌었거나 수집이 실패했다"

# 7. 설정 키 일관성 — references/settings.md 스키마 표가 정본
if [ -f references/settings.md ]; then
  schema=$(sed -n '/^## 스키마/,/^## 예시/p' references/settings.md | grep -oE '^\| `[a-z_]+`' | tr -d '|` ' | sort -u)
  for f in README.md references/settings.md references/base-resolution.md docs/superpowers/specs/*.md; do
    [ -f "$f" ] || continue
    ex=$(awk '/^```yaml/{y=1; next} /^```/{y=0} y' "$f" | grep -oE '^[a-z_]+:' | tr -d ':' | sort -u)
    [ -n "$ex" ] || continue
    extra=$(comm -23 <(printf '%s\n' "$ex") <(printf '%s\n' "$schema"))
    if [ -z "$extra" ]; then ok "설정 키 일관성 $f"; else ng "설정 키 일관성 $f — 스키마에 없는 키: $(echo $extra)"; fi
  done
fi

# 8. 플레이스홀더 — 한글 인접 포함, 매니페스트 포함, grep 오류(rc 2)는 통과로 접지 않는다
ph=$(grep -rnE 'TBD|TODO|FIXME|XXX|<여기[^>]*>|채워 ?넣' skills references README.md .claude-plugin 2>&1); rc=$?
case $rc in
  0) ng "플레이스홀더 발견"; printf '%s\n' "$ph" | sed 's/^/       /' ;;
  1) ok "플레이스홀더 없음" ;;
  *) ng "플레이스홀더 검사 실행 실패 (grep rc=$rc): $ph" ;;
esac

# 9. 금지 동작이 절차로 등장하지 않는가
danger=$(grep -rnE 'push +(-f|--force)|--force-with-lease|gh pr merge[^`]*--squash|git checkout -- \.' skills references 2>/dev/null | grep -vE '하지 않는다|금지|명시된 경우에만|일 때만')
if [ -z "$danger" ]; then ok "금지 동작(force-push·무조건 squash·워킹 트리 전체 되돌리기) 없음"; else ng "금지 동작 발견"; printf '%s\n' "$danger" | sed 's/^/       /'; fi

# 10. 스펙 §9 시나리오의 문서상 근거 — 문장이 사라지면 회귀. 행동 보증은 아니다
assert_has() { if grep -qE "$2" "$1" 2>/dev/null; then ok "앵커 $3"; else ng "앵커 $3 — $1 에 근거 문구 없음 (/$2/)"; fi; }
assert_has skills/work/SKILL.md '브랜치명에서 추론'                '인자 없음 → 브랜치 추론'
assert_has skills/work/SKILL.md 'gh issue list'                    '인자 없음 → 목록 선택'
assert_has skills/work/SKILL.md '임의로 고르지 않는다'              '목록 임의 선택 금지'
assert_has skills/work/SKILL.md 'git fetch origin <base>'          '상태 감지 전 원격 최신화'
for r in 3 4 5; do assert_has references/base-resolution.md "^\| $r \|" "base 판정 ${r}행"; done
assert_has references/base-resolution.md '\*\*묻는다\.?\*\*'       'base 5행은 질문으로 끝남'
for st in '작업 브랜치 없음' '커밋 0' '커밋 있음, PR 없음' 'PR 열려 있음' 'PR 머지됨'; do
  assert_has skills/work/SKILL.md "$st" "재개 상태표: $st"
done
assert_has references/review-agents.md '\*\*항상 명시\.?\*\*'      '모든 Agent 호출에 model 명시'
assert_has skills/work/stages/5-review.md 'model: <review_model>'  '5-review가 model 명시를 지시'
assert_has references/review-agents.md 'git restore --source=HEAD' '정리 되돌리기가 정리 결과에 한정'
assert_has references/preflight.md '검증 명령'                     'review 경로의 검증 명령 확정'
for f in $(grep -rlE 'gh (issue comment|pr create|pr merge|issue create)' skills 2>/dev/null); do
  if grep -qE '승인|게이트|draft' "$f"; then ok "draft 게이트 $f"; else ng "draft 게이트 $f — 외부 게시 명령이 있는데 승인 문구 없음"; fi
done

exit $fail
