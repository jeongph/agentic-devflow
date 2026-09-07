---
name: work
description: "GitHub 이슈 하나를 PR까지 진행한다 — 이슈 확인·범위 확정·계획·구현·리뷰·반영·PR 생성. 범위·계획·PR은 승인을 받고 진행하며, 중단됐으면 브랜치·커밋·PR 상태를 감지해 이어서 한다. 사용법: /agentic-devflow:work [이슈번호]"
disable-model-invocation: true
argument-hint: "[이슈번호]"
---

# Work

GitHub 이슈 하나를 받아 intake → scope → plan → implement → review → apply → ship 순서로 PR까지 진행한다. 같은 이슈로 다시 호출하면 현재 상태를 감지해 이어서 진행한다.

인자: `$ARGUMENTS`

플러그인 루트: `${CLAUDE_PLUGIN_ROOT}`. 이 문서와 아래 참조·단계 문서 안의 `references/…`·`skills/…` 경로는 모두 이 루트 기준이다. 사용자 프로젝트(cwd)에서 같은 이름의 파일을 찾지 않는다.

## 원칙

- **밖으로 나가는 것은 draft를 먼저 보여준다.** 이슈 코멘트, PR 생성, 머지, 별도 이슈 등록은 승인 없이 게시하지 않는다. 계획 승인에 포함되는 것은 셋뿐이다: 브랜치 생성, 이슈 assignee 지정, Project Status 전이. 그 외 예외는 없다.
- **되돌리기 어려운 것은 하지 않는다.** force-push, base 브랜치 직접 커밋, 이슈 임의 close, 설정에 없는 squash 머지, 워킹 트리 전체 되돌리기.
- **추정하지 않는다.** base·이슈·브랜치가 애매하면 후보를 보여주고 묻는다. 로컬 상태로 원격을 추측하지 않는다.
- **멱등적이다.** 같은 이슈로 몇 번을 호출해도 안전하다. 끝난 작업 단계는 건너뛰고, 진행 중인 단계는 이어받는다. 건너뛸지 판단하는 곳은 아래 "상태 감지" 하나뿐이다.

아래 절(사전 확인 → 이슈 번호 결정 → 상태 감지 → 단계 실행 → 완료 보고)은 이 순서대로 수행한다.

---

## 사전 확인

`${CLAUDE_PLUGIN_ROOT}/references/preflight.md`를 따른다. git 레포·gh 인증·GitHub 원격 확인, 설정 파일 읽기, base·prefix 판정, 작업 트리 확인. 검증 명령은 plan 단계에서 확정하므로 여기서는 건너뛴다.

출력: `owner/repo`, 설정값, `base`, `branch_prefix`.

---

## 이슈 번호 결정

| `$ARGUMENTS` | 해석 |
|---|---|
| 숫자 (`146`) | 이슈 번호 |
| 없음, 현재 브랜치가 `<prefix><숫자>-…` | 브랜치명에서 추론 → 재개 |
| 없음, 그 외 | 열린 이슈 목록에서 고르게 한다 |

브랜치 추론 (`<prefix>`는 정규식 메타문자를 이스케이프한 `branch_prefix`):

```bash
git branch --show-current | sed -nE "s#^<prefix>([0-9]+)-.*#\1#p"
```

목록 선택:

```bash
gh issue list --state open --assignee @me --limit 20 --json number,title,labels
```

비어 있으면 `--assignee @me` 없이 다시 조회하고, 목록 위에 "본인 assign 이슈가 없어 전체 열린 이슈를 보여줍니다"를 붙인다. 조회 자체가 실패하면 중단한다. 목록을 보여주고 사용자가 고른다. **임의로 고르지 않는다.**

```
어떤 이슈를 진행할까요?
  #146  [Feature] 주문 취소 시 재고 복원
  #151  [Bug] 자정 넘어가면 집계 누락
```

---

## 상태 감지

이슈 번호 `n`이 정해지면 어디까지 왔는지 본다. 세 묶음을 **이 순서로** 실행한다.

**1) 원격 최신화와 브랜치 식별**

```bash
git fetch origin <base>                                                        # 실패하면 중단
git branch -a --format='%(refname:short)' | grep -E "^(origin/)?<prefix><n>-"   # 작업 브랜치
gh issue view <n> --json comments --jq '[.comments[] | select(.body | test("<!-- agentic-devflow:(scope|plan|review) -->")) | {marker: (.body | capture("agentic-devflow:(?<m>[a-z]+)").m), url: .url, at: .createdAt}]'
```

`origin/<base>`가 최신이어야 커밋 수와 diff 범위가 맞는다. fetch가 실패하면 중단하고 원인을 보고한다. 마커 코멘트가 같은 종류로 여러 개면 **가장 최근 것이 정본**이다.

**2) 정리할 것** (해당하면 먼저 처리)

- 작업 브랜치가 있는데 다른 브랜치에 서 있으면 checkout 여부를 묻는다. 임의로 옮기지 않는다.
- 원격에만 있으면 `git fetch origin <branch>` 후 추적 브랜치로 checkout한다 (확인 후).
- 미커밋 변경은 사전 확인에서 이미 확인받았다.

**3) 상태 측정** (작업 브랜치에 선 뒤)

```bash
git rev-list --count origin/<base>..HEAD                                       # base 대비 커밋 수
gh pr list --head <branch> --state all --json number,state,url,mergedAt
```

| 감지한 상태 | 진입 단계 |
|---|---|
| 작업 브랜치 없음, 마커 없음 | **intake** |
| 작업 브랜치 없음, `scope`만 있음 | 범위 재사용을 제안. 승인 시 **plan** (거절 시 intake) |
| 작업 브랜치 없음, `plan` 있음 | 범위·계획 재사용을 제안. 승인 시 **plan의 3항(브랜치 생성부터)** → implement |
| 브랜치 있음, 커밋 0, `plan` 있음 | 계획 승인 완료로 간주. 정본 `plan` 코멘트를 읽어 **implement** |
| 브랜치 있음, 커밋 0, `plan` 없음 | 사용자가 손으로 만든 브랜치. 브랜치는 재사용하고 **intake** |
| 커밋 있음, PR 없음 | 묻는다: "커밋 N개, PR 없음. 리뷰부터 진행할까요, PR로 바로 갈까요?" → **review** 또는 **ship** |
| PR 열려 있음 | PR 상태(리뷰·CI·코멘트)를 보고하고 묻는다: 재리뷰(**review**) / 머지 정책 진행(**ship**의 머지 절차) / 종료 |
| PR 머지됨 | 완료 보고. base checkout·pull·로컬 브랜치 삭제를 제안 |

- **작업 브랜치가 없으면 어느 단계로 들어가든 plan의 3항(브랜치 생성)을 먼저 거친다.** base 브랜치에서 구현을 시작하는 경로는 없다.
- 리뷰 완료 여부는 마커로 추적하지 않는다. "커밋 있음, PR 없음"에서 한 번 묻는 비용이 마커를 관리하는 비용보다 싸다. 단, 리뷰 루프가 치명·중요를 남긴 채 끝났으면 `review` 마커 코멘트가 남아 있다 — ship이 이것을 확인한다.
- 재개 시 정본으로 삼은 코멘트의 URL과 작성 시각을 보고에 적어, 사용자가 다른 것을 의도했는지 확인할 수 있게 한다.

---

## 단계 실행

진입 단계부터 아래 파일을 순서대로 읽어 그 절차를 따른다. 파일마다 `## 입력` `## 절차` `## 게이트` `## 출력` 네 절이 있다.

1. `${CLAUDE_PLUGIN_ROOT}/skills/work/stages/1-intake.md` — 이슈 확인
2. `${CLAUDE_PLUGIN_ROOT}/skills/work/stages/2-scope.md` — 구현 범위 확정
3. `${CLAUDE_PLUGIN_ROOT}/skills/work/stages/3-plan.md` — 구현 계획, 브랜치 생성
4. `${CLAUDE_PLUGIN_ROOT}/skills/work/stages/4-implement.md` — 구현·커밋
5. `${CLAUDE_PLUGIN_ROOT}/skills/work/stages/5-review.md` — 리뷰 팬아웃
6. `${CLAUDE_PLUGIN_ROOT}/skills/work/stages/6-apply.md` — 리뷰 반영·재리뷰·정리
7. `${CLAUDE_PLUGIN_ROOT}/skills/work/stages/7-ship.md` — 히스토리·push·PR·머지 정책

- `## 게이트`에 이르면 **멈추고** 사용자 응답을 기다린다. 승인 후 다음으로 간다.
- `## 출력`의 항목을 다음 단계의 `## 입력`으로 넘긴다. 세션이 길어져 잃어버렸으면 이슈의 `scope`·`plan`·`note`·`review` 마커 코멘트에서 다시 읽는다. 마커로 남지 않는 출력(리뷰 집계 원문 등)은 복원하지 않고 다시 만든다.
- 단계 안에서 막히면(검증 실패 반복, 권한 없음, 정보 부족, 외부 명령 실패) 다음 단계로 넘어가지 않고 보고한다.

---

## 완료 보고

```
#146 주문 취소 시 재고 복원 — 완료

  브랜치     feature/146-restore-stock-on-cancel (develop에서 분기, a1b2c3d)
  커밋       5개
  리뷰       치명 0 · 중요 2 반영 · 제안 3 중 1 반영 (code-reviewer, silent-failure-hunter, kent-beck / opus)
  히스토리   docs/history/2026-09-07-001-claude-재고-복원.md
  보드       In progress (Project #4)
  PR         https://github.com/org/repo/pull/152 (base: develop, Closes #146)
  머지       대기 (merge: manual)

다음: PR 리뷰 후 머지. 피드백이 오면 /agentic-devflow:work 146 을 다시 실행하면 재리뷰로 들어간다.
```

- `히스토리`·`보드` 줄은 건너뛰었거나 실패했으면 그 사실과 원인을 적는다 (예: `보드  변경 실패 — project 스코프 없음. gh auth refresh -s project 후 수동으로 옮기세요`). 흐름 중간에 흘린 경고는 여기서 반드시 다시 보인다.
- `Refs`로 연결한 PR이면 `PR` 줄에 "이슈는 열려 있음, 완료 조건: …"을 적는다.
- 머지까지 했으면 `머지` 줄에 머지 커밋과 브랜치 정리 결과를 적는다.

---

## 중단 조건

오케스트레이터가 직접 판단하는 조건이다. 단계 안의 중단 조건은 각 단계 파일의 절차·게이트 절이 정한다.

| 상황 | 동작 |
|---|---|
| git 레포 아님 / `gh` 인증 없음 / GitHub 원격 아님 | 사전 확인에서 중단, 이유 보고 |
| 설정 파일 YAML 파싱 실패 | 중단. 설정 없음으로 간주하지 않는다 |
| 이슈 없음 / 닫힘 / 목록 조회 실패 | 없으면 중단. 닫혔으면 알리고 계속 여부를 묻는다 |
| 미커밋 변경 · 다른 브랜치에 서 있음 | 알리고 확인. 임의 stash·commit·checkout 금지 |
| `git fetch` 실패 | 중단. 로컬 base로 조용히 진행하지 않는다 |
| 작업 브랜치 없이 implement 이후 단계로 진입하려 함 | plan의 브랜치 생성을 먼저 수행 |
