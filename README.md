# agentic-devflow

[![version](https://img.shields.io/github/v/release/jeongph/agentic-devflow?label=version&color=blue)](https://github.com/jeongph/agentic-devflow/releases)
[![license](https://img.shields.io/github/license/jeongph/agentic-devflow?color=lightgrey)](LICENSE)

GitHub 이슈를 바탕으로 구현, 리뷰, PR 생성을 진행합니다. 중단된 작업도 이어서 진행할 수 있습니다.

`/agentic-devflow:work 146` 한 줄로 이슈 확인, 구현 범위 확정, 계획, 구현, 리뷰(opus), 리뷰 반영, PR 생성까지 진행합니다. 세션이 끊겨도 같은 명령을 다시 치면 브랜치·커밋·PR 상태를 보고 이어서 합니다.

## 개념

이슈를 구현하려면 범위를 정하고 계획, 구현, 리뷰, PR 생성을 차례로 진행해야 합니다. 세션이 끊기면 이전 작업이 어디까지 진행됐는지도 확인해야 합니다.

이 플러그인은 그 순서를 절차로 고정하고, 진행 상태를 git과 GitHub에서 읽어 재개합니다.

### 주요 동작

| | 이 플러그인 |
|---|---|
| **재개** | 브랜치·커밋·PR 상태와 이슈 코멘트를 읽어 다음 단계를 정한다. 같은 명령을 다시 실행해도 완료한 단계는 건너뛴다. 별도 상태 파일은 만들지 않는다 |
| **리뷰** | pr-review-toolkit 에이전트를 직접 호출하고 리뷰 모델을 지정한다. 기본값은 `opus`이며, `model: inherit` 설정과 관계없이 같은 모델을 사용한다 |
| **승인 절차** | 이슈 코멘트·PR·머지는 초안이나 실행 내용을 확인받은 뒤 진행한다. force-push, base 브랜치 직접 커밋, 임의 squash는 금지한다 |
| **브랜치 모델** | Git Flow와 GitHub Flow 모두 지원한다. 기준 브랜치(`base`)와 브랜치 접두사를 판정표로 정하고, 판단하기 어려우면 사용자에게 묻는다 |
| **도메인** | 분야별 지식과 리뷰어는 별도 플러그인에서 제공한다. 사용할 에이전트를 설정에 추가해 리뷰에 참여시킨다 |

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

현재 브랜치가 `feature/146-…`이면 이슈 번호를 146으로 판단합니다. 커밋이 3개 있고 PR이 없으면 다음과 같이 묻습니다.

```
#146 — 커밋 3개, PR 없음. 리뷰부터 진행할까요, PR로 바로 갈까요?
```

### 리뷰만

```
/agentic-devflow:review tests errors
```

pr-test-analyzer와 silent-failure-hunter만 opus로 실행하고, 치명적이거나 중요한 지적 사항을 확인해 반영합니다.

## 프로젝트 설정

저장소의 `.claude/agentic-devflow.md`에 기준 브랜치와 분야별 리뷰어를 지정할 수 있습니다. 지정한 값은 자동 판정보다 우선하며, 모든 키는 생략할 수 있습니다.

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
3. `develop`이 없고 장기간 유지하는 다른 브랜치(`staging`·`dev`·`next`…)도 없으면 기본 브랜치
4. 그 외에는 **묻습니다**. 추정하지 않습니다

첫 실행에서 판정 결과를 확인받고 설정 파일에 기록을 제안합니다.

## 설계 원칙

- **공통 절차를 담당한다.** Spring과 React 등 기술 분야에 관계없이 같은 작업 순서와 승인 절차를 적용한다.
- **게시 전에 초안을 확인받는다.** 이슈 코멘트·PR·머지는 승인 없이 게시하지 않는다.
- **추정하지 않는다.** base·이슈·브랜치가 애매하면 후보를 보여주고 묻는다.
- **단계별 파일과 설정으로 확장한다.** 작업 단계는 `stages/`에 파일을 추가하고, 브랜치 프리셋은 표에 행을 추가한다. 리뷰어는 설정에 이름을 등록한다. 전체 진행을 담당하는 스킬 본문은 바꾸지 않는다.

## 라이선스

[MIT](LICENSE)
