# agentic-devflow 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** GitHub 이슈 하나를 범위 확정·계획·구현·리뷰(opus)·반영·PR까지 커맨드 하나로 진행하는 Claude Code 플러그인 `agentic-devflow` v0.1.0을 만든다.

**Architecture:** 코드가 아니라 절차 문서로 이루어진 플러그인이다. 오케스트레이터 스킬(`work`)이 상태를 감지해 `stages/` 파일 7개를 순서대로 따르고, 판정 규칙은 `references/` 문서 3개가 담는다. `review` 스킬은 5·6단계만 단독 실행한다. pr-review-toolkit은 매니페스트 `dependencies`로 필수 선언한다.

**Tech Stack:** Claude Code 플러그인(plugin.json, skills/), `gh` CLI, bash 검증 스크립트, GitHub Actions(재사용 릴리스 워크플로우)

**Spec:** `docs/superpowers/specs/2026-09-07-agentic-devflow-design.md`

## Global Constraints

- 스킬·참조 문서·README 본문은 **한글**. 코드·식별자·명령은 영어.
- `commands/`·`agents/`·`hooks/` 디렉토리를 만들지 않는다 (스펙 §3).
- `work`·`review` 스킬은 `disable-model-invocation: true` (사용자만 호출).
- 리뷰 에이전트 호출은 **모두 `model: <review_model>`(기본 opus) 명시** (스펙 §6.2).
- 밖으로 나가는 동작(이슈 코멘트·PR·머지)은 draft 확인 게이트 필수. force-push·base 직접 커밋·임의 squash 금지 (스펙 §4.5).
- 단계 파일은 `## 입력` `## 절차` `## 게이트` `## 출력` 네 절로 통일 (스펙 §4.4).
- 문서 안에 `TBD`·`TODO` 플레이스홀더를 남기지 않는다.
- 커밋 메시지는 워크스페이스 커밋 컨벤션(Conventional Commits, 한글 제목 50자 이내).
- 이 레포는 아직 골격이 없으므로 이번 플랜의 커밋은 `main`에 직접 한다 (스펙 §10).

**문서 산출물에 대한 주의:** 이 플랜의 "코드"는 마크다운이다. 각 태스크는 파일의 프론트매터·절 구성·반드시 담아야 할 규칙(스펙 절 번호로 추적)을 명시하고, 검증은 `scripts/check.sh`와 `claude plugin validate --strict`로 한다. 본문 문장은 구현 시 작성하되 명시된 규칙을 빠뜨리지 않는다.

---

## 파일 구조

| 파일 | 책임 |
|---|---|
| `.claude-plugin/plugin.json` | 매니페스트, pr-review-toolkit 의존성 |
| `.gitignore` `LICENSE` `.github/workflows/auto-release.yml` | 레포 메타 (git-flow와 동일 형식) |
| `scripts/check.sh` | 구조 검사: 매니페스트 필드·스킬 프론트매터·단계 파일 네 절·참조 경로 실재·플레이스홀더 |
| `references/base-resolution.md` | base·prefix 판정표, 프리셋, 첫 실행 확인·기록 절차 (스펙 §6.1) |
| `references/settings.md` | 프로젝트 설정 파일 스키마·우선순위·읽는 법 (스펙 §7) |
| `references/review-agents.md` | 리뷰 에이전트 선택표, 호출 규약, 프롬프트 골격, 집계 형식 (스펙 §6.2) |
| `skills/work/SKILL.md` | 오케스트레이터: 인자 해석, 사전 확인, 상태 감지·재개, 단계 실행 규칙, 게이트 원칙 (스펙 §4.1–4.3, 4.5) |
| `skills/work/stages/1-intake.md` … `7-ship.md` | 단계별 절차 (스펙 §4.4) |
| `skills/review/SKILL.md` | 5·6단계 단독 실행 (스펙 §5) |
| `README.md` | 개요·설치·컴포넌트·사용 예·설정·설계 원칙 |

---

### Task 1: 레포 골격과 검증 하네스

**Files:**
- Create: `.claude-plugin/plugin.json`, `.gitignore`, `LICENSE`, `.github/workflows/auto-release.yml`, `scripts/check.sh`

**Interfaces:**
- Produces: `scripts/check.sh` — 인자 없음, 실패 항목을 `[FAIL] …`로 출력하고 exit 1. 이후 모든 태스크가 이것으로 검증한다.

- [ ] **Step 1: plugin.json 작성** (스펙 §3 그대로)

```json
{
  "name": "agentic-devflow",
  "version": "0.1.0",
  "description": "GitHub 이슈 하나를 PR까지 — 범위 확정·계획·구현·리뷰(opus)·반영·PR 생성을 커맨드 하나로, 중단돼도 이어서",
  "author": { "name": "JeongUk Park", "url": "https://github.com/jeongph" },
  "homepage": "https://github.com/jeongph/agentic-devflow",
  "repository": "https://github.com/jeongph/agentic-devflow",
  "license": "MIT",
  "keywords": ["workflow", "github", "issue", "pull-request", "code-review", "claude-code"],
  "dependencies": [
    { "name": "pr-review-toolkit", "marketplace": "claude-plugins-official" }
  ]
}
```

- [ ] **Step 2: 메타 파일 작성**

`.gitignore`:
```
.DS_Store
.remember/
.orca/
*.log
node_modules/
```

`LICENSE`: `../git-flow/LICENSE`를 그대로 복사 (MIT, Copyright (c) 2026 JeongUk Park).

`.github/workflows/auto-release.yml`: `../git-flow/.github/workflows/auto-release.yml`을 그대로 복사 (claude-plugins 재사용 워크플로우 호출).

- [ ] **Step 3: scripts/check.sh 작성**

```bash
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
  case "$m" in
    stages/*) p="skills/work/$m" ;;
    *) p="$m" ;;
  esac
  if [ -f "$p" ]; then ok "링크 $m"; else ng "링크 $m → $p 없음"; fi
done < <(grep -rhoE '(references|stages)/[A-Za-z0-9_.-]+\.md' skills references 2>/dev/null | sort -u)

# 6. 플레이스홀더
if grep -rnE '\b(TBD|TODO)\b' skills references README.md 2>/dev/null; then ng "플레이스홀더(TBD/TODO) 발견"; else ok "플레이스홀더 없음"; fi

exit $fail
```

`chmod +x scripts/check.sh`.

- [ ] **Step 4: 검증 실행**

Run: `claude plugin validate . --strict`
Expected: `✔ Validation passed` (스킬이 없어도 매니페스트만으로 통과)

Run: `scripts/check.sh`
Expected: 매니페스트 항목 `[PASS]`, 스킬·단계·참조 항목은 `[FAIL]` (아직 없음), exit 1

- [ ] **Step 5: 커밋**

```bash
git add .claude-plugin .gitignore LICENSE .github scripts
git commit -m "chore: 플러그인 골격과 구조 검사 스크립트 추가"
```

---

### Task 2: base 브랜치 판정표

**Files:**
- Create: `references/base-resolution.md`

**Interfaces:**
- Produces: 판정 결과 두 값 `base`, `branch_prefix`. `work`·`review`의 사전 확인이 이 문서 절차를 따른다.

- [ ] **Step 1: 문서 작성** — 다음 절을 이 순서로 담는다.

1. `# base 브랜치 판정` — 한 줄 요약: 이슈→PR 경로가 필요로 하는 값은 `base`와 `branch_prefix` 둘뿐이며, 브랜치 모델은 이 두 값의 프리셋이다.
2. `## 프리셋` — 표: `git-flow`(base=`develop`, prefix=`feature/`), `github-flow`(base=기본 브랜치, prefix=`feature/`). 트렁크 기반+짧은 브랜치는 github-flow와 동작이 같다는 비고.
3. `## 판정 순서` — 스펙 §6.1 표 5행 그대로. 각 행에 실행 명령을 붙인다:
   - 1행: 설정 파일 `.claude/agentic-devflow.md` frontmatter의 `base` (읽는 법은 `references/settings.md`)
   - 2행: 프로젝트 CLAUDE.md에서 "Git Flow"/"GitHub Flow"/base 브랜치명 선언 탐색
   - 3행: `git ls-remote --heads origin develop`
   - 4행: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` + `git ls-remote --heads origin`으로 장수 브랜치 후보(`dev` `development` `staging` `next` `release*`, 기본 브랜치가 아닌 `master`) 없음 확인
   - 5행: 후보 목록을 보여주고 묻는다. 추정 금지.
4. `## 첫 실행 확인과 기록` — 3·4·5행으로 판정한 경우 "이 레포는 base=`<x>`, prefix=`<y>`로 봤습니다. 맞나요?"를 묻고, 확정되면 `.claude/agentic-devflow.md`에 기록을 **제안**한다(파일 생성도 밖으로 나가는 변경이므로 승인 후). 기록하면 다음부터 1행에서 끝난다.
5. `## 프리셋에 없는 레포` — 설정 파일 `base`로 직접 지정. 새 프리셋은 이 문서 표에 행 추가.
6. `## 금지` — 로컬 브랜치 목록으로 기본 브랜치를 추측하지 않는다. `git ls-remote`/`gh` 실패 시 중단하고 원인을 보고한다.

- [ ] **Step 2: 검증**

Run: `scripts/check.sh | grep base-resolution`
Expected: `[PASS] references/base-resolution.md`

- [ ] **Step 3: 커밋**

```bash
git add references/base-resolution.md
git commit -m "feat(references): base 브랜치·prefix 판정표 추가"
```

---

### Task 3: 프로젝트 설정 파일 스키마

**Files:**
- Create: `references/settings.md`

**Interfaces:**
- Produces: 키 8개의 이름·타입·기본값. `work`·`review`·다른 참조 문서가 이 이름을 그대로 쓴다: `base` `branch_prefix` `project` `reviewers` `review_model` `simplify` `merge` `merge_method`.

- [ ] **Step 1: 문서 작성**

1. `# 프로젝트 설정 파일` — 경로 `.claude/agentic-devflow.md`, 레포에 체크인, YAML frontmatter만 해석하고 본문은 자유 메모.
2. `## 스키마` — 표: 키 / 타입 / 기본값 / 설명.

| 키 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `base` | string | 자동 판정 (`references/base-resolution.md`) | 분기·PR 대상 브랜치 |
| `branch_prefix` | string | `feature/` | 작업 브랜치 접두사 |
| `project` | number | 없음 → Status 갱신 건너뜀 | org Project 번호 |
| `reviewers` | string[] | `[]` | 도메인 리뷰어 에이전트명 (`플러그인:에이전트`) |
| `review_model` | string | `opus` | 모든 리뷰 에이전트 호출에 명시할 모델 |
| `simplify` | boolean | `true` | 리뷰 통과 후 code-simplifier 1회 |
| `merge` | `manual` \| `auto` | `manual` | PR 생성 후 머지 여부 |
| `merge_method` | `merge` \| `rebase` \| `squash` | `merge` | `gh pr merge` 방식. squash는 명시할 때만 |

3. `## 예시` — 스펙 §7의 YAML 블록 그대로.
4. `## 우선순위` — 설정 파일 > 프로젝트 CLAUDE.md 선언 > 자동 판정/기본값. 커밋 컨벤션·히스토리 규칙처럼 CLAUDE.md가 이미 담는 것은 여기 중복하지 않는다.
5. `## 읽는 법` — Read 도구로 파일을 읽고 첫 `---` … `---` 사이를 YAML로 해석한다. 파일이 없으면 모든 키가 기본값. 알 수 없는 키는 무시하되 한 줄 알린다.

- [ ] **Step 2: 검증**

Run: `scripts/check.sh | grep settings`
Expected: `[PASS] references/settings.md`

- [ ] **Step 3: 커밋**

```bash
git add references/settings.md
git commit -m "feat(references): 프로젝트 설정 파일 스키마 추가"
```

---

### Task 4: 리뷰 에이전트 선택표와 호출 규약

**Files:**
- Create: `references/review-agents.md`

**Interfaces:**
- Consumes: `review_model` `reviewers` `simplify` (Task 3)
- Produces: 함수처럼 쓰이는 절차 세 개 — **선택**(diff → 에이전트 목록), **호출**(Agent 도구 파라미터 규약), **집계**(보고서 형식). 5·6단계와 `review` 스킬이 이것을 참조한다.

- [ ] **Step 1: 문서 작성**

1. `# 리뷰 에이전트` — 왜 `/pr-review-toolkit:review-pr` 커맨드를 쓰지 않고 직접 호출하는지 (inherit 에이전트 4종에 opus를 강제할 유일한 방법).
2. `## 선택표` — 스펙 §6.2 표 그대로 + 각 행의 **판정 방법**:
   - code-reviewer: 항상
   - pr-test-analyzer: 변경 파일 경로에 `test`/`spec`/`__tests__` 포함, 또는 프로덕션 파일에 새 함수·클래스가 생겼는데 대응 테스트 파일 변경이 없음
   - silent-failure-hunter: diff에 `try`/`catch`/`except`/`rescue`/`.catch(`/`fallback`/`default:`/로깅 호출 추가·변경
   - type-design-analyzer: diff에 `class`/`record`/`interface`/`enum`/`type`/`struct`/`data class` 선언 추가·변경
   - comment-analyzer: diff에 주석·docstring·`.md` 변경
   - code-simplifier: 6 apply 통과 후 `simplify`가 true일 때 1회
   - `reviewers`: 지정된 경우 항상
3. `## 관점 인자 매핑` — `review` 스킬 인자 → 에이전트: `code`→code-reviewer, `tests`→pr-test-analyzer, `errors`→silent-failure-hunter, `comments`→comment-analyzer, `types`→type-design-analyzer, `simplify`→code-simplifier, `all`→선택표대로. 인자가 있으면 선택표 대신 인자를 따른다(도메인 리뷰어는 `all`·인자 없음일 때만).
4. `## 호출 규약` — Agent 도구 파라미터: `subagent_type`은 `pr-review-toolkit:<name>` 또는 `reviewers`의 값 그대로, `model`은 `review_model` **항상 명시**, `description`은 `review:<name>`. 독립적이므로 **한 메시지에서 병렬 호출**. 프롬프트 골격(코드 블록):
   ```
   리뷰 대상: `git diff origin/<base>...HEAD` 범위. 변경 파일: <목록>
   이슈 #<n>: <제목> — <요약 한 줄>
   확정된 범위: <포함/제외>
   결과는 심각도(치명/중요/제안)별로, 각 항목에 `파일:라인`과 근거를 포함해 한글로 보고하라.
   ```
5. `## 집계` — 보고서 형식(코드 블록): `## 리뷰 결과` → `### 치명 (N)` `### 중요 (N)` `### 제안 (N)` `### 잘한 점`. 항목 형식 `- [에이전트명] 설명 — \`파일:라인\``. 같은 지적이 여러 에이전트에서 나오면 하나로 합치고 에이전트명을 나열.
6. `## 도메인 리뷰어 계약` — Agent 도구로 호출 가능한 이름, diff 범위·파일 목록을 받아 심각도별 지적을 `파일:라인`과 함께 돌려준다. 이 계약을 만족하면 어떤 플러그인의 에이전트든 `reviewers`에 넣을 수 있다.

- [ ] **Step 2: 검증**

Run: `scripts/check.sh | grep -E 'review-agents|링크'`
Expected: `[PASS] references/review-agents.md`, 문서가 언급한 `references/settings.md` 링크 `[PASS]`

- [ ] **Step 3: 커밋**

```bash
git add references/review-agents.md
git commit -m "feat(references): 리뷰 에이전트 선택표와 호출 규약 추가"
```

---

### Task 5: `work` 오케스트레이터 스킬

**Files:**
- Create: `skills/work/SKILL.md`

**Interfaces:**
- Consumes: `references/base-resolution.md`(Task 2), `references/settings.md`(Task 3)
- Produces: 단계 파일 계약 — 각 `stages/N-<name>.md`는 `## 입력` `## 절차` `## 게이트` `## 출력` 네 절. 오케스트레이터는 파일을 읽어 그 절차를 따르고, 출력 절의 항목을 다음 단계 입력으로 넘긴다.

- [ ] **Step 1: 프론트매터**

```yaml
---
name: work
description: "GitHub 이슈 하나를 PR까지 진행한다 — 이슈 확인·범위 확정·계획·구현·리뷰(opus)·반영·PR 생성. 중단됐으면 브랜치·커밋·PR 상태를 감지해 이어서 진행한다. 사용법: /agentic-devflow:work [이슈번호]"
disable-model-invocation: true
argument-hint: "[이슈번호]"
---
```

- [ ] **Step 2: 본문** — 다음 절을 이 순서로.

1. `# Work` — 한 줄 정의 + 인자 `$ARGUMENTS`.
2. `## 원칙` — 스펙 §4.5 세 원칙(밖으로 나가는 것은 draft 확인 / 되돌리기 어려운 것은 하지 않는다 / 추정하지 않는다) + "멱등적: 같은 이슈로 몇 번 호출해도 안전, 끝난 단계는 건너뛴다".
3. `## 1. 사전 확인` — 스펙 §4.2 네 항목을 명령과 함께:
   - `git rev-parse --git-dir`
   - `gh auth status` · `gh repo view --json nameWithOwner,defaultBranchRef`
   - 설정 파일 읽기 → `references/settings.md`
   - base·prefix 판정 → `references/base-resolution.md`
   - 실패 시 메시지 예시(코드 블록): "이 플러그인은 GitHub 이슈·PR을 전제합니다. 원격이 GitHub가 아니거나 gh 인증이 없습니다."
4. `## 2. 이슈 번호 결정` — 스펙 §4.1 표. 브랜치 추론 정규식 `^<prefix>([0-9]+)-`. 목록 선택은 `gh issue list --state open --assignee @me --limit 20`, 비면 `--assignee` 없이. 임의 선택 금지.
5. `## 3. 상태 감지` — 스펙 §4.3 표 + 감지 명령:
   - `git branch -a --format='%(refname:short)' | grep -E "^(origin/)?<prefix><n>-"`
   - `git rev-list --count origin/<base>..HEAD`
   - `gh pr list --head <branch> --state all --json number,state,url,mergedAt`
   - 미커밋 변경(`git status --porcelain`)·다른 브랜치 체크아웃 상태면 먼저 알리고 확인. 임의 stash·commit·checkout 금지.
   - "커밋 있음 + PR 없음"은 묻는다: "리뷰부터 진행할까요, PR로 바로 갈까요?"
6. `## 4. 단계 실행` — `stages/` 파일을 진입 단계부터 순서대로 읽어 따른다. 파일 목록 7개를 경로로 나열. 각 파일의 `## 게이트`에서 멈추고 승인 후 다음으로. 출력 절 항목을 다음 단계 입력으로 유지.
7. `## 5. 완료 보고` — 형식(코드 블록): 이슈, 브랜치, 커밋 수, 리뷰 반영 요약, PR URL, 머지 여부, 다음 행동.
8. `## 중단 조건` — 스펙 §8 표.

- [ ] **Step 3: 검증**

Run: `scripts/check.sh | grep -E 'work/SKILL|링크 stages'`
Expected: `[PASS] skills/work/SKILL.md 프론트매터`; `링크 stages/…` 7건은 아직 `[FAIL]` (다음 태스크에서 생성)

Run: `claude plugin validate . --strict`
Expected: `✔ Validation passed`

- [ ] **Step 4: 커밋**

```bash
git add skills/work/SKILL.md
git commit -m "feat(work): 이슈→PR 오케스트레이터 스킬 추가"
```

---

### Task 6: 단계 1·2 — intake, scope

**Files:**
- Create: `skills/work/stages/1-intake.md`, `skills/work/stages/2-scope.md`

**Interfaces:**
- 1-intake 출력 → 2-scope 입력: `이슈 요약`(무엇·왜·관련 이슈·선례)
- 2-scope 출력 → 3-plan 입력: `확정된 범위`(목표/포함/제외/영향 범위/리스크), 범위 코멘트 URL

- [ ] **Step 1: 1-intake.md** — 네 절.

- 입력: 이슈 번호 `n`.
- 절차 (스펙 §4.4-1):
  1. `gh issue view <n> --json number,title,body,state,labels,assignees,url,comments`
  2. 상위·하위 이슈: `gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){issue(number:$n){parent{number title} subIssues(first:50){nodes{number title state}}}}}' -F o=<owner> -F r=<repo> -F n=<n>` — 오류(필드 미지원)면 건너뛰고 한 줄 알림.
  3. `state`가 CLOSED면 알리고 계속할지 묻는다.
  4. 중복 후보: `gh issue list --state open --search "<제목 핵심어 2~3개>" --json number,title` 결과에서 `n` 제외. 있으면 알림만(닫지 않는다).
  5. `docs/history/_INDEX.md`가 있으면 `grep -i "<핵심어>"`로 선례 3건 이내 추려 읽는다. 인덱스 전체를 읽지 않는다.
- 게이트: 없음 (읽기 전용). 단, 이슈 CLOSED 질문만.
- 출력: `이슈 요약` 형식(코드 블록): 제목·유형·라벨 / 무엇을 / 왜 / 상위·하위 이슈 / 기존 코멘트의 분석 요지 / 선례.

- [ ] **Step 2: 2-scope.md** — 네 절.

- 입력: `이슈 요약`.
- 절차 (스펙 §4.4-2):
  1. 영향 범위 탐색 — Explore 서브에이전트 또는 Grep/Glob으로 관련 모듈·진입점·테스트 위치를 찾는다.
  2. 범위 문서 작성 형식(코드 블록): `목표` / `포함` / `제외` / `영향 범위` (파일·모듈) / `리스크·불확실한 점`.
  3. 이슈 코멘트 draft 작성 (한글, 위 형식 그대로, 첫 줄에 `<!-- agentic-devflow:scope -->` 마커 — 재개 시 이 마커로 찾는다).
- 게이트: (a) 범위 확정 질문 — 이견이 있으면 수정 후 재확인. (b) 코멘트 draft 승인 → `gh issue comment <n> --body-file <tmp>`.
- 출력: `확정된 범위`, 코멘트 URL.

- [ ] **Step 3: 검증**

Run: `scripts/check.sh | grep -E '1-intake|2-scope'`
Expected: 두 파일 `[PASS]`, 링크 `[PASS]`

- [ ] **Step 4: 커밋**

```bash
git add skills/work/stages/1-intake.md skills/work/stages/2-scope.md
git commit -m "feat(work): intake·scope 단계 추가"
```

---

### Task 7: 단계 3·4 — plan, implement

**Files:**
- Create: `skills/work/stages/3-plan.md`, `skills/work/stages/4-implement.md`

**Interfaces:**
- 3-plan 출력 → 4-implement 입력: `계획`(순서 있는 단계, 각 단계의 파일·검증 명령·커밋 지점), 브랜치명, 계획 코멘트 URL
- 4-implement 출력 → 5-review 입력: 커밋 목록, 검증 결과

- [ ] **Step 1: 3-plan.md** — 네 절.

- 입력: `확정된 범위`, `base`, `branch_prefix`, 설정 `project`.
- 절차 (스펙 §4.4-3):
  1. 계획 형식(코드 블록): 단계 번호 / 할 일 / 대상 파일 / 검증 명령 / 커밋 메시지 초안. 검증 명령은 프로젝트의 실제 명령(예: `./gradlew test`, `pnpm test`)을 찾아 적는다 — 찾지 못하면 사용자에게 묻는다.
  2. 계획 코멘트 draft — 첫 줄 `<!-- agentic-devflow:plan -->` 마커.
  3. 승인 후 순서: (a) `gh issue comment` (b) assignee 없으면 `gh issue edit <n> --add-assignee @me` (c) `git fetch origin <base>` → `git checkout -b <prefix><n>-<slug> origin/<base>`; slug는 이슈 제목 영문 kebab-case 5단어 내외 소문자; 동명 브랜치 존재 시(`git branch -a | grep`) 알리고 묻는다 (d) `project`가 있으면 Status → In progress: `gh project item-list <project> --owner <org> --format json`으로 item id, `gh project field-list`로 Status field id·옵션 id, `gh project item-edit --project-id --id --field-id --single-select-option-id`. 이슈가 Project에 없으면 `gh project item-add`. 실패는 경고만.
- 게이트: 계획 승인, 코멘트 draft 승인.
- 출력: 브랜치명, 분기점 SHA(`git rev-parse --short origin/<base>`), 계획 코멘트 URL.

- [ ] **Step 2: 4-implement.md** — 네 절.

- 입력: `계획`.
- 절차 (스펙 §4.4-4):
  1. 계획 단계마다 구현 → 검증 명령 실행 → 통과 시 커밋. 실패 상태로 커밋하지 않는다.
  2. 커밋 메시지는 프로젝트 커밋 컨벤션(CLAUDE.md) 준수. 없으면 Conventional Commits 한글 제목.
  3. 계획에서 벗어나는 결정·트러블슈팅이 생기면 이슈 코멘트 draft(마커 `<!-- agentic-devflow:note -->`) → 승인 → 게시.
  4. push 하지 않는다. 사용자가 요청하면 `git push -u origin <branch>`.
  5. 도메인 스킬은 자동 발화에 맡긴다. 직접 호출하지 않는다.
- 게이트: 계획 이탈 시 코멘트 draft 승인. 검증 실패가 반복되면(같은 단계 3회) 멈추고 보고.
- 출력: 커밋 목록(`git log origin/<base>..HEAD --oneline`), 마지막 검증 결과.

- [ ] **Step 3: 검증**

Run: `scripts/check.sh | grep -E '3-plan|4-implement'`
Expected: 두 파일 `[PASS]`

- [ ] **Step 4: 커밋**

```bash
git add skills/work/stages/3-plan.md skills/work/stages/4-implement.md
git commit -m "feat(work): plan·implement 단계 추가"
```

---

### Task 8: 단계 5·6 — review, apply

**Files:**
- Create: `skills/work/stages/5-review.md`, `skills/work/stages/6-apply.md`

**Interfaces:**
- Consumes: `references/review-agents.md`의 선택·호출·집계 절차, 설정 `review_model` `reviewers` `simplify`
- 5-review 출력 → 6-apply 입력: `리뷰 결과`(집계 형식)
- 6-apply 출력 → 7-ship 입력: 반영 내역, 미반영 사유, 최종 검증 결과

- [ ] **Step 1: 5-review.md** — 네 절.

- 입력: `base`, 변경 파일 목록(`git diff --name-only origin/<base>...HEAD`), 이슈 요약, 확정된 범위, 설정.
- 절차 (스펙 §4.4-5): `references/review-agents.md`의 **선택** → **호출**(모든 Agent 호출에 `model: <review_model>`, 병렬) → **집계**. 이 파일은 절차를 복제하지 않고 참조 문서의 절 이름을 가리킨다.
- 게이트: 없음 (보고만). 단, 변경 파일이 0개면 중단하고 알린다.
- 출력: `리뷰 결과`.

- [ ] **Step 2: 6-apply.md** — 네 절.

- 입력: `리뷰 결과`, 검증 명령.
- 절차 (스펙 §4.4-6):
  1. 치명·중요 항목마다 코드를 열어 타당성 확인. 타당하면 반영, 아니면 근거와 함께 "미반영" 기록. 리뷰어 말을 맹목적으로 따르지 않는다.
  2. 제안 항목은 목록으로 보여주고 반영할 것을 고르게 한다.
  3. 반영 후 검증 실행 → 커밋 (`fix:`/`refactor:` 등 성격대로).
  4. 치명·중요가 남았으면 5-review 재실행. 루프 카운터 최대 3회, 초과 시 잔여 목록과 함께 사용자에게 넘긴다.
  5. 통과 후 `simplify`가 true면 `pr-review-toolkit:code-simplifier`를 `model: <review_model>`로 1회 호출 → 검증 → 통과 시 커밋, 실패 시 `git checkout -- .`로 되돌리고 알린다.
- 게이트: 제안 항목 선택. 3회 초과 시 사용자 판단.
- 출력: 반영 내역, 미반영 사유, 최종 검증 결과.

- [ ] **Step 3: 검증**

Run: `scripts/check.sh | grep -E '5-review|6-apply'`
Expected: 두 파일 `[PASS]`

- [ ] **Step 4: 커밋**

```bash
git add skills/work/stages/5-review.md skills/work/stages/6-apply.md
git commit -m "feat(work): review·apply 단계 추가"
```

---

### Task 9: 단계 7 — ship

**Files:**
- Create: `skills/work/stages/7-ship.md`

**Interfaces:**
- Consumes: 설정 `merge` `merge_method`, `base`, 이슈 번호, 6-apply 출력
- Produces: PR URL, 머지 여부

- [ ] **Step 1: 7-ship.md** — 네 절. 절차는 스펙 §4.4-7 여섯 단계 순서 그대로:

1. 전체 검증 재실행. 실패면 PR 만들지 않는다.
2. `docs/history/`가 있으면 프로젝트 CLAUDE.md의 히스토리 규칙(파일명·frontmatter·본문)대로 작성·커밋. 규칙을 못 찾으면 건너뛰고 알린다.
3. `git push -u origin <branch>`.
4. PR draft 형식(코드 블록): 제목(이슈 제목 기반, 커밋 컨벤션 제목 규칙) / 본문 `## 요약` `## 변경 내역` `## 검증` `## 이슈` (`Closes #<n>` 기본; 이슈 본문에 머지 밖 완료 조건이 있으면 `Refs #<n>`). 승인 후 `gh pr create --base <base> --title … --body-file <tmp> --assignee @me`.
5. 머지: `merge=auto`면 `gh pr checks <num> --watch` 통과 후 `gh pr merge <num> --<merge_method> --delete-branch`. `manual`이면 URL 보고 후 멈춤. 설정 없고 CLAUDE.md 정책 있으면 그것. `--squash`는 `merge_method: squash`일 때만.
6. 머지됐으면 `git checkout <base> && git pull && git branch -d <branch>`. Status Done은 GitHub 자동화에 맡긴다.

- 게이트: PR draft 승인. `merge=auto`여도 머지 직전에 한 줄 확인("CI 통과. 머지합니다").
- 출력: PR URL, 머지 여부, 정리 결과.

- [ ] **Step 2: 검증**

Run: `scripts/check.sh`
Expected: `review/SKILL.md`·`README` 관련 항목 외 모두 `[PASS]`

- [ ] **Step 3: 커밋**

```bash
git add skills/work/stages/7-ship.md
git commit -m "feat(work): ship 단계 추가"
```

---

### Task 10: `review` 단독 스킬

**Files:**
- Create: `skills/review/SKILL.md`

**Interfaces:**
- Consumes: `skills/work/stages/5-review.md`, `6-apply.md`, `references/review-agents.md`의 관점 인자 매핑, `work` SKILL.md의 사전 확인 절

- [ ] **Step 1: 프론트매터**

```yaml
---
name: review
description: "현재 브랜치의 변경(base 대비)을 pr-review-toolkit 에이전트(opus)와 프로젝트 도메인 리뷰어로 리뷰하고 치명·중요 항목을 반영한다. 사용법: /agentic-devflow:review [code|tests|errors|comments|types|simplify|all]"
disable-model-invocation: true
argument-hint: "[aspects]"
---
```

- [ ] **Step 2: 본문**

1. `# Review` — 용도 두 가지: PR에 사람 피드백이 달린 뒤 재리뷰, `work` 없이 리뷰만.
2. `## 사전 확인` — `skills/work/SKILL.md`의 "1. 사전 확인"과 같은 절차(설정 파일·base 판정). 현재 브랜치가 base 자신이면 중단.
3. `## 관점 인자` — `$ARGUMENTS`를 `references/review-agents.md`의 "관점 인자 매핑"으로 해석. 없으면 `all`.
4. `## 실행` — `skills/work/stages/5-review.md` → `6-apply.md` 순서로 따른다. 복제하지 않는다.
5. `## 보고` — 반영 내역·미반영 사유·최종 검증. push는 하지 않는다(사용자 요청 시).

- [ ] **Step 3: 검증**

Run: `scripts/check.sh`
Expected: README 관련 항목 제외 전부 `[PASS]` (README는 아직 없음 → 플레이스홀더 검사만 통과)

- [ ] **Step 4: 커밋**

```bash
git add skills/review/SKILL.md
git commit -m "feat(review): 리뷰·반영 단독 실행 스킬 추가"
```

---

### Task 11: README와 최종 검증

**Files:**
- Create: `README.md`

- [ ] **Step 1: README 작성** — git-flow README 구성을 따른다.

1. 제목 + 배지(version·license) + 한 줄 설명.
2. `## 개념` — 왜 만들었나(이슈 기반 작업의 반복 순서와 compact 복원 문제), 무엇이 다른가(멱등 재개, opus 강제 리뷰, draft 게이트).
3. `## 설치` — `/plugin marketplace add jeongph/claude-plugins`, `/plugin install agentic-devflow@jeongph-claude-plugins`. pr-review-toolkit이 자동 설치된다는 안내. 요구사항: `git`, `gh`(인증), GitHub 원격.
4. `## 컴포넌트` — 표: `/agentic-devflow:work [이슈번호]`, `/agentic-devflow:review [aspects]`, 참조 문서 3개.
5. `## 사용 예` — `work 146` 전체 흐름 예시 출력, 인자 없는 재개 예시, `review tests errors`.
6. `## 프로젝트 설정` — `.claude/agentic-devflow.md` 예시(스펙 §7)와 base 판정 요약.
7. `## 설계 원칙` — 프로세스/도메인 분리, 밖으로 나가는 것은 draft, 추정하지 않음, 확장은 파일 추가.
8. `## 라이선스` — MIT.

- [ ] **Step 2: 전체 검증**

Run: `scripts/check.sh`
Expected: 전부 `[PASS]`, exit 0

Run: `claude plugin validate . --strict`
Expected: `✔ Validation passed`

Run: `claude plugin validate . --json`
Expected: 리포트에 skills `work`·`review`가 잡히고 error 0건

로드 확인: `claude --plugin-dir .`로 세션을 띄워 `/agentic-devflow:work`·`/agentic-devflow:review`가 자동완성에 뜨는지 확인한다. 대화형이라 스크립트로 못 하므로 브리핑에서 사용자에게 확인을 요청한다.

Run: `plugin-dev:plugin-validator` 에이전트로 구조 검사, `plugin-dev:skill-reviewer`로 두 SKILL.md description 검토. 지적은 반영.

- [ ] **Step 3: 커밋·푸시**

```bash
git add README.md
git commit -m "docs: README 추가"
git push -u origin main
```

---

### Task 12: 마켓플레이스 등록 (사용자 확인 후 수행)

**Files:**
- Modify: `../claude-plugins/.claude-plugin/marketplace.json`

이 태스크는 플러그인을 공개 설치 가능하게 만드는 배포 단계다. Task 11까지 끝나고 리뷰 반영이 완료된 뒤, **사용자 확인을 받고** 수행한다.

- [ ] **Step 1: 등록 항목 추가** — `plugins[]`에:

```json
{
  "name": "agentic-devflow",
  "description": "GitHub 이슈 하나를 PR까지 — 범위 확정·계획·구현·리뷰(opus)·반영·PR 생성을 커맨드 하나로, 중단돼도 이어서",
  "source": { "source": "url", "url": "https://github.com/jeongph/agentic-devflow.git", "sha": "<main HEAD 40자>" }
}
```

루트에 `"allowCrossMarketplaceDependenciesOn": ["claude-plugins-official"]` 추가 (없으면 설치 시 `cross-marketplace` 오류).

- [ ] **Step 2: 검증**

Run: `claude plugin validate ../claude-plugins --strict`
Expected: `✔ Validation passed`

- [ ] **Step 3: PR**

claude-plugins 레포에서 `feature/add-agentic-devflow` 브랜치 → 커밋 `feat: agentic-devflow 플러그인 등록` → `gh pr create --assignee @me` → 워크스페이스 머지 정책대로 머지.

- [ ] **Step 4: 설치 확인**

`/plugin install agentic-devflow@jeongph-claude-plugins` 후 `claude plugin list`에 agentic-devflow와 pr-review-toolkit이 함께 뜨는지 확인.
