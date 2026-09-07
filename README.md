# agentic-devflow

[![version](https://img.shields.io/github/v/release/jeongph/agentic-devflow?label=version&color=blue)](https://github.com/jeongph/agentic-devflow/releases)
[![license](https://img.shields.io/github/license/jeongph/agentic-devflow?color=lightgrey)](LICENSE)

GitHub 이슈 하나를 PR까지 끌고 가는 Claude Code 플러그인.

`/agentic-devflow:work 146` 한 줄로 이슈 확인, 구현 범위 확정, 계획, 구현, 리뷰(opus), 리뷰 반영, PR 생성까지 진행합니다. 세션이 끊겨도 같은 명령을 다시 치면 브랜치·커밋·PR 상태를 보고 이어서 합니다.

## 개념

이슈 기반 작업은 매번 같은 순서를 밟습니다. 이슈 읽기 → 범위 정하기 → 계획 → 구현 → 리뷰 → 반영 → PR. 문제는 이 순서를 사람이 매 세션 구술로 지시하고, 컨텍스트가 압축되면 "어디까지 왔는지"도 사람이 복원한다는 것입니다.

이 플러그인은 그 순서를 절차로 고정하고, 진행 상태를 git과 GitHub에서 읽어 재개합니다.

### 무엇이 다른가

| | 이 플러그인 |
|---|---|
| **재개** | 멱등적. 브랜치 없음 → 커밋 없음 → PR 없음 → PR 있음 순으로 상태를 감지해 다음 단계부터. 상태 파일을 만들지 않고 git과 이슈 코멘트에서 읽는다 |
| **리뷰** | pr-review-toolkit 에이전트를 커맨드가 아니라 **직접 호출**해 전부 `opus`로 통일. `model: inherit` 에이전트가 세션 모델로 도는 것을 막는다 |
| **게이트** | 밖으로 나가는 것(이슈 코멘트·PR·머지)은 반드시 draft 확인. 되돌리기 어려운 것(force-push·base 직접 커밋·임의 squash)은 하지 않는다 |
| **브랜치 모델** | Git Flow / GitHub Flow를 플러그인으로 나누지 않는다. 필요한 건 base 브랜치와 prefix 둘뿐이라, 판정표로 정하고 애매하면 묻는다 |
| **도메인** | 도메인 지식·리뷰어는 담지 않는다. 별도 플러그인의 에이전트를 설정 한 줄로 리뷰에 끼운다 |

## 설치

```
/plugin marketplace add jeongph/claude-plugins
/plugin install agentic-devflow@jeongph-claude-plugins
```

[pr-review-toolkit](https://github.com/anthropics/claude-plugins-official)이 의존성으로 함께 설치·활성화됩니다.

**요구사항** — `git`, [`gh`](https://cli.github.com/) (인증 완료), GitHub 원격이 있는 저장소.

## 컴포넌트

| 종류 | 이름 | 역할 |
|---|---|---|
| 스킬 (슬래시 커맨드) | `/agentic-devflow:work [이슈번호]` | 이슈→PR 전체 진행. 인자 없으면 브랜치명에서 추론하거나 열린 이슈에서 선택 |
| 스킬 (슬래시 커맨드) | `/agentic-devflow:review [관점...]` | 현재 브랜치 리뷰·반영만. 관점: `code` `tests` `errors` `comments` `types` `simplify` `all` |
| 참조 | `references/preflight.md` | 두 스킬이 공유하는 사전 확인 절차 |
| 참조 | `references/base-resolution.md` | base 브랜치·prefix 판정표 |
| 참조 | `references/review-agents.md` | diff → 리뷰 에이전트 선택표, 호출 규약, 집계 형식, 정리 절차 |
| 참조 | `references/settings.md` | 프로젝트 설정 파일 스키마 |

## 사용 예

### 이슈에서 PR까지

```
/agentic-devflow:work 146
```

```
#146 주문 취소 시 재고 복원   [Feature] · backend · open
무엇을   주문 취소 시 해당 라인의 재고를 원복한다
왜       취소해도 재고가 줄어든 채 남아 품절 오판 발생
…

구현 범위
목표      취소된 주문 라인의 재고가 원복된다
포함      CancelService → StockRestorer 호출, 동시성 보호(@Version), 테스트
제외      취소 알림 발송 (별도 이슈 제안)
이 범위로 진행할까요?
```

범위 확정 → 계획 승인 → 브랜치 `feature/146-restore-stock-on-cancel` 생성 → 구현·커밋 → 리뷰(opus) → 반영 → PR draft 승인 → PR 생성.

```
#146 주문 취소 시 재고 복원 — 완료

  브랜치   feature/146-restore-stock-on-cancel (develop에서 분기, a1b2c3d)
  커밋     5개
  리뷰     치명 0 · 중요 2 반영 · 제안 3 중 1 반영
  PR       https://github.com/org/repo/pull/152 (base: develop, Closes #146)
  머지     대기 (merge: manual)
```

### 중단된 작업 이어서

```
/agentic-devflow:work
```

`feature/146-…` 브랜치에 서 있으면 146을 추론하고, 커밋 3개·PR 없음을 감지해 묻습니다.

```
#146 — 커밋 3개, PR 없음. 리뷰부터 진행할까요, PR로 바로 갈까요?
```

### 리뷰만

```
/agentic-devflow:review tests errors
```

pr-test-analyzer·silent-failure-hunter만 opus로 돌리고 치명·중요를 반영합니다.

## 프로젝트 설정

레포에 `.claude/agentic-devflow.md`를 두면 판정을 건너뛰고 도메인 리뷰어를 끼울 수 있습니다. 모든 키가 선택입니다.

```yaml
---
base: develop                  # 생략 시 자동 판정
branch_prefix: feature/        # 기본 feature/
project: 4                     # Project 번호. 있으면 Status를 In progress로
project_owner: my-org          # 생략 시 레포 owner. 개인 Project면 "@me"
reviewers:                     # 도메인 리뷰어 (예시 — 해당 플러그인 설치 시)
  - spring-backend:kent-beck
  - spring-backend:vladimir-khorikov
review_model: opus             # 기본 opus. opus | sonnet | haiku
simplify: true                 # 리뷰 통과 후 code-simplifier 1회
merge: manual                  # manual(기본) | auto. auto도 머지 직전 확인 1회
merge_method: merge            # merge(기본) | rebase | squash
---
```

### base 브랜치 판정

설정에 `base`가 없으면 이 순서로 정합니다.

1. 프로젝트 CLAUDE.md의 워크플로우 선언
2. 원격에 `develop`이 있으면 `develop`
3. `develop`이 없고 다른 장수 브랜치(`staging`·`dev`·`next`…)도 없으면 기본 브랜치
4. 그 외에는 **묻습니다**. 추정하지 않습니다

첫 실행에서 판정 결과를 확인받고 설정 파일에 기록을 제안합니다.

## 설계 원칙

- **프로세스와 도메인을 분리한다.** 이 플러그인은 순서와 게이트만 안다. Spring이든 React든 같은 절차로 돈다.
- **밖으로 나가는 것은 draft 먼저.** 이슈 코멘트·PR·머지는 승인 없이 게시하지 않는다.
- **추정하지 않는다.** base·이슈·브랜치가 애매하면 후보를 보여주고 묻는다.
- **확장은 파일 추가로.** 단계는 `stages/`에 파일 하나, 브랜치 프리셋은 표에 행 하나, 리뷰어는 설정에 이름 하나. 오케스트레이터 본문은 바뀌지 않는다.

## 라이선스

[MIT](LICENSE)
