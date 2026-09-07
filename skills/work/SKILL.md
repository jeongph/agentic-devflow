---
name: work
description: "GitHub 이슈 하나를 PR까지 진행한다 — 이슈 확인·범위 확정·계획·구현·리뷰(opus)·반영·PR 생성. 중단됐으면 브랜치·커밋·PR 상태를 감지해 이어서 진행한다. 사용법: /agentic-devflow:work [이슈번호]"
disable-model-invocation: true
argument-hint: "[이슈번호]"
---

# Work

GitHub 이슈 하나를 받아 범위 확정 → 계획 → 구현 → 리뷰 → 반영 → PR까지 진행한다. 같은 이슈로 다시 호출하면 현재 상태를 감지해 이어서 진행한다.

인자: `$ARGUMENTS`

## 원칙

- **밖으로 나가는 것은 draft를 먼저 보여준다.** 이슈 코멘트, PR 생성, 머지. 승인 없이 게시하지 않는다. 예외 없음.
- **되돌리기 어려운 것은 하지 않는다.** force-push, base 브랜치 직접 커밋, 이슈 임의 close, 설정에 없는 squash 머지.
- **추정하지 않는다.** base·이슈·브랜치가 애매하면 후보를 보여주고 묻는다. 로컬 상태로 원격을 추측하지 않는다.
- **멱등적이다.** 같은 이슈로 몇 번을 호출해도 안전하다. 끝난 단계는 건너뛰고, 진행 중인 단계는 이어받는다.

실행 흐름은 1 → 5 순서다. 단계를 건너뛰거나 병합하지 않는다.

---

## 1. 사전 확인

```bash
git rev-parse --git-dir                                   # git 레포인가
gh auth status                                            # gh 인증
gh repo view --json nameWithOwner,defaultBranchRef        # GitHub 원격인가
```

- git 레포가 아니면 중단한다.
- `gh auth status`나 `gh repo view`가 실패하면 중단한다:

```
이 플러그인은 GitHub 이슈·PR을 전제합니다. 원격이 GitHub가 아니거나 gh 인증이 없습니다.
gh auth login 후 다시 실행하세요.
```

- 프로젝트 설정 파일을 읽는다 → `references/settings.md`. 없으면 기본값.
- base 브랜치와 prefix를 판정한다 → `references/base-resolution.md`. 자동 판정이면 첫 실행에 확인받고 설정 파일 기록을 제안한다.

이후 단계는 `base`, `branch_prefix`, 설정값을 입력으로 쓴다.

---

## 2. 이슈 번호 결정

| `$ARGUMENTS` | 해석 |
|---|---|
| 숫자 (`146`) | 이슈 번호 |
| 없음, 현재 브랜치가 `<branch_prefix><숫자>-…` | 브랜치명에서 추론 → 재개 |
| 없음, 그 외 | 열린 이슈 목록에서 고르게 한다 |

브랜치 추론:

```bash
git branch --show-current | sed -nE "s#^${branch_prefix}([0-9]+)-.*#\1#p"
```

목록 선택:

```bash
gh issue list --state open --assignee @me --limit 20 --json number,title,labels
```

비어 있으면 `--assignee @me` 없이 다시 조회한다. 목록을 보여주고 사용자가 고른다. **임의로 고르지 않는다.**

```
어떤 이슈를 진행할까요?
  #146  [Feature] 주문 취소 시 재고 복원
  #151  [Bug] 자정 넘어가면 집계 누락
```

---

## 3. 상태 감지

이슈 번호 `n`이 정해지면 어디까지 왔는지 본다.

```bash
git status --porcelain                                                                  # 미커밋 변경
git branch -a --format='%(refname:short)' | grep -E "^(origin/)?${branch_prefix}${n}-"   # 작업 브랜치
git rev-list --count origin/<base>..HEAD                                                 # base 대비 커밋 수 (브랜치 체크아웃 후)
gh pr list --head <branch> --state all --json number,state,url,mergedAt
```

먼저 정리할 것:

- 미커밋 변경이 있으면 알리고 확인받는다. 임의로 stash·커밋하지 않는다.
- 작업 브랜치가 있는데 다른 브랜치에 서 있으면 checkout 여부를 묻는다. 임의로 옮기지 않는다.
- 원격에만 있으면 `git fetch origin <branch>` 후 추적 브랜치로 checkout한다 (확인 후).

| 감지한 상태 | 진입 단계 |
|---|---|
| 작업 브랜치 없음 | **1 intake**. 단, 이슈 코멘트에 `<!-- agentic-devflow:scope -->` / `plan` 마커가 있으면 재사용을 제안하고, 승인 시 그 단계 다음부터 |
| 브랜치 있음, base 대비 커밋 0 | 계획 승인 완료로 간주. 이슈의 `plan` 코멘트를 읽어 **4 implement** |
| 커밋 있음, PR 없음 | 묻는다: "커밋 N개, PR 없음. 리뷰부터 진행할까요, PR로 바로 갈까요?" → **5 review** 또는 **7 ship** |
| PR 열려 있음 | PR 상태(리뷰·CI·코멘트)를 보고하고 묻는다: 재리뷰(`/agentic-devflow:review`) / 머지 정책 진행 / 종료 |
| PR 머지됨 | 완료 보고. base checkout·pull·로컬 브랜치 삭제를 제안 |

리뷰 완료 여부는 마커로 추적하지 않는다. "커밋 있음, PR 없음"에서 한 번 묻는 비용이 마커를 관리하는 비용보다 싸다.

---

## 4. 단계 실행

진입 단계부터 아래 파일을 순서대로 읽어 그 절차를 따른다. 파일마다 `## 입력` `## 절차` `## 게이트` `## 출력` 네 절이 있다.

1. `stages/1-intake.md` — 이슈 확인
2. `stages/2-scope.md` — 구현 범위 확정
3. `stages/3-plan.md` — 구현 계획, 브랜치 생성
4. `stages/4-implement.md` — 구현·커밋
5. `stages/5-review.md` — 리뷰 팬아웃 (opus)
6. `stages/6-apply.md` — 리뷰 반영·재리뷰·정리
7. `stages/7-ship.md` — 히스토리·push·PR·머지 정책

- `## 게이트`에 이르면 **멈추고** 사용자 응답을 기다린다. 승인 후 다음으로 간다.
- `## 출력`의 항목을 다음 단계의 `## 입력`으로 넘긴다. 세션이 길어져 잃어버렸으면 이슈 코멘트(마커)에서 다시 읽는다.
- 단계 안에서 막히면(검증 실패 반복, 권한 없음, 정보 부족) 다음 단계로 넘어가지 않고 보고한다.

---

## 5. 완료 보고

```
#146 주문 취소 시 재고 복원 — 완료

  브랜치   feature/146-restore-stock-on-cancel (develop에서 분기, a1b2c3d)
  커밋     5개
  리뷰     치명 0 · 중요 2 반영 · 제안 3 중 1 반영 (code-reviewer, silent-failure-hunter, kent-beck)
  PR       https://github.com/org/repo/pull/152 (base: develop, Closes #146)
  머지     대기 (merge: manual)

다음: PR 리뷰 후 머지. 피드백이 오면 /agentic-devflow:review 로 재리뷰.
```

머지까지 했으면 `머지` 줄에 머지 커밋과 브랜치 정리 결과를 적는다.

---

## 중단 조건

| 상황 | 동작 |
|---|---|
| git 레포 아님 / `gh` 인증 없음 / GitHub 원격 아님 | 사전 확인에서 중단, 이유 보고 |
| 이슈 없음 / 닫힘 | 없으면 중단. 닫혔으면 알리고 계속 여부를 묻는다 |
| 미커밋 변경 · 다른 브랜치에 서 있음 | 알리고 확인. 임의 stash·commit·checkout 금지 |
| 브랜치명 충돌 | 알리고 다시 묻는다 |
| `git fetch`/`pull` 실패 | 중단. 로컬 base로 조용히 진행하지 않는다 |
| 검증(테스트·빌드) 실패 | 다음 단계로 가지 않는다. 고치거나 보고 |
| Project Status 갱신 실패 | 경고만 남기고 흐름 유지 |
| 리뷰 3회 후에도 치명·중요 잔존 | 잔여 목록과 함께 사용자에게 넘긴다 |
| 히스토리 규칙을 못 찾음 | 건너뛰고 알린다 |
