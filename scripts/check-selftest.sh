#!/usr/bin/env bash
# check.sh 자체 검증 — 일부러 깨뜨린 사본에서 check.sh가 FAIL을 내는지 본다.
# 사용: scripts/check-selftest.sh   → 원본 통과 1건 + 파손 검출 N건. 하나라도 놓치면 exit 1
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
ROOT=$PWD
TMP=$(mktemp -d) || exit 2
trap 'rm -rf "$TMP"' EXIT
fail=0
ok() { printf '[PASS] 자체검증: %s\n' "$1"; }
ng() { printf '[FAIL] 자체검증: %s — 깨뜨렸는데 check.sh가 통과시킴\n' "$1"; fail=1; }

snapshot() { rm -rf "$TMP/w"; mkdir -p "$TMP/w"; (cd "$ROOT" && git ls-files -z --cached --others --exclude-standard | tar --null -cf - -T -) | (cd "$TMP/w" && tar xf -); }
expect_fail() { local label=$1; shift; snapshot; ( cd "$TMP/w" && "$@" ) >/dev/null 2>&1
  if bash "$TMP/w/scripts/check.sh" >/dev/null 2>&1; then ng "$label"; else ok "$label"; fi; }

# 0. 원본은 반드시 통과해야 한다. 이 항목이 없으면 무조건 FAIL을 내는 check.sh도 만점을 받는다.
snapshot
if bash "$TMP/w/scripts/check.sh" >/dev/null 2>&1; then ok "원본 통과"; else
  printf '[FAIL] 자체검증: 원본이 통과하지 못함 — check.sh에 거짓 양성이 있다\n'; bash "$TMP/w/scripts/check.sh" | grep FAIL; fail=1; fi

# 1~N. 의도적 파손. 변이 명령에 백틱을 쓰지 않는다 (명령 치환으로 실행된다).
expect_fail "단계 파일의 절 이름 변경"        sed -i.bak 's/^## 게이트$/## 승인 게이트/' skills/work/stages/5-review.md
expect_fail "절 이름에 접미사"                sed -i.bak 's/^## 입력$/## 입력값/' skills/work/stages/1-intake.md
expect_fail "네 절이 코드펜스 안에만"         sh -c 'printf "# x\n\n\`\`\`\n## 입력\n## 절차\n## 게이트\n## 출력\n\`\`\`\n" > skills/work/stages/2-scope.md'
expect_fail "disable-model-invocation 삭제"  sed -i.bak '/^disable-model-invocation: true$/d' skills/work/SKILL.md
expect_fail "프론트매터 키를 본문으로 이동"   sh -c "sed -i.bak '/^name: work\$/d' skills/work/SKILL.md && printf '\nname: work\n' >> skills/work/SKILL.md"
expect_fail "프론트매터 닫는 --- 삭제"        sh -c "awk 'BEGIN{c=0} /^---\$/{c++; if(c==2) next} {print}' skills/review/SKILL.md > t && mv t skills/review/SKILL.md"
expect_fail "스킬 name ↔ 디렉토리 불일치"     sed -i.bak 's/^name: work$/name: worker/' skills/work/SKILL.md
expect_fail "존재하지 않는 경로 참조"         sed -i.bak 's#skills/work/stages/5-review.md#skills/work/stages/9-nope.md#' skills/review/SKILL.md
expect_fail "SKILL.md의 루트 기준 상대 경로"  sh -c 'printf "%s\n" "설정 스키마는 references/settings.md 참고." >> skills/work/SKILL.md'
expect_fail "중첩 경로 깨진 링크"             sh -c 'printf "%s\n" "프리셋 상세는 references/presets/gitlab.md 참고." >> references/base-resolution.md'
expect_fail "설정 키 이름 문서별 상이"        sed -i.bak 's/review_model/model/g' references/settings.md
expect_fail "새 단계 파일에 네 절 없음"       sh -c 'printf "# 8. foo\n" > skills/work/stages/8-foo.md'
expect_fail "SKILL.md 단계 목록 누락"         sed -i.bak '/stages\/7-ship.md/d' skills/work/SKILL.md
expect_fail "한글 붙은 TODO"                  sh -c 'printf "\n검증명령TODO미정\n" >> references/settings.md'
expect_fail "FIXME 플레이스홀더"              sh -c 'printf "\nFIXME: 판정표 미완\n" >> references/base-resolution.md'
expect_fail "README 삭제 (grep rc 2)"         rm README.md
expect_fail "plugin.json name 변경"           sh -c "python3 -c \"import json;p='.claude-plugin/plugin.json';d=json.load(open(p));d['name']='x';json.dump(d,open(p,'w'),ensure_ascii=False)\""
expect_fail "pr-review-toolkit 의존성 제거"   sh -c "python3 -c \"import json;p='.claude-plugin/plugin.json';d=json.load(open(p));d['dependencies']=[];json.dump(d,open(p,'w'),ensure_ascii=False)\""
expect_fail "base 판정 5행 삭제"              sed -i.bak '/^| 5 |/d' references/base-resolution.md
expect_fail "model 항상 명시 문구 삭제"       sed -i.bak 's/\*\*항상 명시\.\*\*/명시/' references/review-agents.md
expect_fail "force-push가 절차로 등장"        sh -c 'printf "%s\n" "막히면 git push --force 로 밀어넣는다." >> skills/work/stages/7-ship.md'
expect_fail "워킹 트리 전체 되돌리기 재등장"  sh -c 'printf "%s\n" "실패하면 git checkout -- . 로 되돌린다." >> references/review-agents.md'
expect_fail "상태 감지의 fetch 삭제"          sed -i.bak '/git fetch origin <base>/d' skills/work/SKILL.md

exit $fail
