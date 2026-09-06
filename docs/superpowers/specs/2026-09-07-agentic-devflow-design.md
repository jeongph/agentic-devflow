# agentic-devflow 설계

> GitHub 이슈 하나를 받아 범위 확정 → 계획 → 구현 → 리뷰 → 반영 → PR까지 끌고 가는 Claude Code 플러그인.
> 작성일 2026-09-07. 브레인스토밍 결과를 정리한 스펙이며, 구현 플랜은 이 문서를 근거로 별도 작성한다.

## 1. 목적과 범위

### 문제

이슈 기반 작업은 매번 같은 순서를 밟는다 — 이슈 확인, 구현 범위 확인, 구현 계획, 구현, pr-review-toolkit 리뷰(opus), 리뷰 반영, PR 생성. 지금은 이 순서를 사람이 매 세션 구술로 지시하고, 세션이 끊기면(compact) 어느 단계까지 왔는지도 사람이 복원한다.

### 목표

- 위 순서를 **커맨드 하나**(`/agentic-devflow:work <이슈번호>`)로 실행한다.
- 세션이 끊겨도 같은 커맨드를 다시 치면 **현재 상태를 감지해 이어서** 진행한다.
- 도메인(백엔드·웹·앱)과 무관하게 동작한다. 도메인 지식·리뷰어는 별도 플러그인이 담당한다.
- 확장은 **파일 추가**로 한다. 단계·브랜치 프리셋·리뷰어를 늘려도 오케스트레이터 본문은 바뀌지 않는다.

### 범위 밖 (이번 스펙에서 다루지 않음)

| 항목 | 이유 | 후속 |
|---|---|---|
| release·hotfix 경로 (태그·back-merge) | 이슈 생명주기가 아니라 릴리스 생명주기 | 같은 판정표를 읽는 스킬을 나중에 추가 |
| Spring 백엔드 설계·보안·테스트 지식, kent-beck·vladimir-khorikov 리뷰어 | 도메인 종속 | 별도 플러그인 `spring-backend` (다음 서브 프로젝트) |
| GitHub 외 호스팅(GitLab 등) | 워크스페이스 표준이 GitHub 이슈 + org Project | 없음 (YAGNI) |
| superpowers 등 프로세스 플러그인 연동 | 불필요한 절차·토큰 증가 우려 | 없음. 자체 절차만 내장 |
| 세션 마무리 검사(claude-tidy) 연동 | 별도 플러그인이 이미 담당 | 없음. ship 단계가 필요한 최소(히스토리 문서)만 직접 수행 |

## 2. 정체성과 경계

agentic-devflow는 **프로세스 오케스트레이터**다. 무엇을 만드는지는 모르고, 어떤 순서로 어떤 게이트를 거쳐 어디로 내보내는지만 안다.

| 플러그인 | 담당 | agentic-devflow와의 관계 |
|---|---|---|
| **agentic-devflow** (이 문서) | 이슈→PR 오케스트레이션, base 브랜치 판정, GitHub 연동(이슈·브랜치·PR·Project) | — |
| pr-review-toolkit (공식) | 범용 코드 리뷰 에이전트 6종 | **필수 의존성**. 리뷰 단계가 에이전트를 직접 opus로 호출 |
| spring-backend (예정) | Spring 설계·보안·테스트 스킬, 페르소나 리뷰어 | 의존 없음. 스킬은 description으로 자동 발화, 리뷰어는 프로젝트 설정의 `reviewers`로 지정 |
| git-flow (기존) | Git Flow 릴리스 절차·가드 훅 | 의존 없음. 같이 설치돼도 충돌 없음 (이 플러그인은 base에 직접 커밋하지 않는다) |

브랜치 모델별로 플러그인을 나누지 않는다. 이슈→PR 경로가 브랜치 모델에서 필요로 하는 값은 base 브랜치와 브랜치 prefix 둘뿐이라, 모델은 이 두 값의 프리셋에 불과하다 (§6.1).

GitHub Flow라는 이름의 스킬·커맨드는 만들지 않는다. GitHub Flow는 특정 브랜치 모델의 고유명사라 "GitHub 기반 워크플로우"와 섞이면 혼란만 준다.

## 3. 구성

```
agentic-devflow/
├── .claude-plugin/plugin.json
├── skills/
│   ├── work/
│   │   ├── SKILL.md                 # /agentic-devflow:work [이슈번호] — 오케스트레이터
│   │   └── stages/
│   │       ├── 1-intake.md          # 이슈 확인
│   │       ├── 2-scope.md           # 구현 범위 확정
│   │       ├── 3-plan.md            # 구현 계획 → 브랜치 생성
│   │       ├── 4-implement.md       # 구현·커밋
│   │       ├── 5-review.md          # 리뷰 팬아웃
│   │       ├── 6-apply.md           # 리뷰 반영·재리뷰·정리
│   │       └── 7-ship.md            # push·PR·히스토리·머지 정책
│   └── review/
│       └── SKILL.md                 # /agentic-devflow:review [aspects] — 5·6단계만 단독 실행
├── references/
│   ├── base-resolution.md           # base 브랜치·prefix 판정표와 프리셋
│   ├── review-agents.md             # diff 특성 → 리뷰 에이전트 선택표
│   └── settings.md                  # 프로젝트 설정 파일 스키마
├── docs/superpowers/specs/          # 이 문서
├── README.md
├── LICENSE
├── .gitignore
└── .github/workflows/auto-release.yml
```

- `commands/` 디렉토리는 두지 않는다. 스킬은 그 자체로 `/플러그인:스킬` 슬래시 커맨드이므로 스킬 하나로 "스킬 + 슬래시 커맨드"를 동시에 만족한다. `work`·`review`에는 `disable-model-invocation: true`를 붙여 **사용자만** 호출하게 한다. 무거운 흐름이 자연어에 반응해 자동 발화하지 않도록 하기 위해서다.
- `agents/` 디렉토리는 두지 않는다. 리뷰어는 의존성과 도메인 플러그인에서 빌려 쓰고, 코드 탐색은 내장 Explore 서브에이전트로 한다.
- `hooks/`는 두지 않는다. 지금 필요한 자동화가 없다.
- 스킬·참조 문서 본문은 **한글**로 쓴다 (git-flow·claude-tidy와 동일).

### plugin.json

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

버전 제약은 걸지 않는다. pr-review-toolkit의 plugin.json에 `version` 필드가 없어 제약을 걸면 태그 매칭 실패로 로드가 막힌다.

## 4. `work` 커맨드

### 4.1 인자

```
/agentic-devflow:work            # 인자 없음
/agentic-devflow:work 146        # 이슈 번호
```

| 입력 | 해석 |
|---|---|
| 숫자 | GitHub 이슈 번호 |
| 없음, 현재 브랜치가 `<prefix><숫자>-…` 형태 | 브랜치명에서 이슈 번호 추론 → 재개 |
| 없음, 그 외 | 열린 이슈 목록(`gh issue list`, 본인 assign 우선)을 보여주고 고르게 한다. 임의로 고르지 않는다 |

### 4.2 사전 확인 (모든 실행의 첫 동작)

1. git 레포인가. 아니면 중단.
2. `gh auth status`가 성공하고 `gh repo view`로 원격을 읽을 수 있는가. 아니면 "이 플러그인은 GitHub 이슈·PR을 전제한다"고 알리고 중단.
3. 프로젝트 설정 파일(`.claude/agentic-devflow.md`, §7)을 읽는다. 없으면 기본값·자동 판정으로 진행한다.
4. base 브랜치와 prefix를 판정한다 (§6.1). 자동 판정이면 첫 실행에 확인받고 설정 파일 기록을 제안한다.

### 4.3 상태 감지와 재개

오케스트레이터는 **멱등적**이다. 같은 이슈로 몇 번을 호출해도 안전하며, 이미 끝난 단계는 건너뛴다.

| 감지한 상태 | 진입 단계 |
|---|---|
| 작업 브랜치(`<prefix><n>-*`) 없음 | 1 intake부터. 단, 이슈에 이 플러그인이 남긴 범위·계획 코멘트가 있으면 재사용을 제안 |
| 브랜치 있음, base 대비 커밋 없음 | 계획 승인 완료로 간주. 이슈 코멘트에서 계획을 읽어 4 implement |
| 커밋 있음, PR 없음 | 사용자에게 묻는다: "리뷰부터 진행 / PR로 바로" (리뷰 완료 여부는 마커 없이 판단하지 않는다) |
| PR 열려 있음 | PR 상태 보고. 리뷰 재실행(`review`) 또는 종료를 제안 |
| PR 머지됨 | 완료 보고. 로컬 브랜치 정리를 제안 |

브랜치가 다른 곳에 체크아웃돼 있거나 미커밋 변경이 있으면 **먼저 알리고 확인받는다.** 임의로 stash·커밋·checkout하지 않는다.

### 4.4 단계

각 단계는 `stages/N-<name>.md` 파일 하나다. 오케스트레이터는 파일을 순서대로 읽어 절차를 따른다. 파일 구조는 **입력 / 절차 / 게이트 / 출력** 네 절로 통일한다.

#### 1 intake — 이슈 확인

- `gh issue view <n>`으로 제목·본문·라벨·assignee·상태·코멘트 전체를 읽는다.
- 상위 이슈·sub-issue를 GraphQL로 조회한다. API 미지원이면 건너뛴다.
- 이슈가 닫혀 있으면 알리고 계속할지 묻는다.
- 같은 작업의 중복 이슈가 있는지 제목 키워드로 검색해 있으면 알린다 (`gh issue list --search`).
- 프로젝트에 `docs/history/_INDEX.md`가 있으면 키워드로 선례를 찾아 참고한다. 인덱스 전체를 읽지 않는다.
- 출력: 이슈 요약(무엇을, 왜, 관련 이슈, 선례) 한 화면.

#### 2 scope — 구현 범위 확정

- 이슈 요약을 바탕으로 코드베이스를 탐색한다 (Explore 서브에이전트 활용 가능).
- 범위 문서를 만든다: **목표 / 포함 / 제외 / 영향 범위(파일·모듈) / 리스크·불확실한 점**.
- **게이트**: 사용자에게 보여주고 확정받는다. 이견이 있으면 수정 후 다시 확인.
- 확정된 범위를 이슈 코멘트로 남긴다. **draft를 보여주고 승인 후 게시**한다. (워크스페이스 규칙: 원인 분석·개선 방법은 이슈 코멘트에)
- 출력: 확정된 범위.

#### 3 plan — 구현 계획과 브랜치

- 범위를 **순서 있는 단계**로 쪼갠다. 단계마다 대상 파일, 검증 방법(테스트·빌드 명령), 커밋 지점을 적는다.
- **게이트**: 계획을 보여주고 승인받는다.
- 승인 후:
  1. 계획을 이슈 코멘트로 남긴다 (draft 승인 후). 재개 시 이 코멘트가 계획의 정본이다.
  2. 이슈에 본인이 assign돼 있지 않으면 assign한다.
  3. 브랜치를 만든다: `git fetch origin <base>` → `git checkout -b <prefix><n>-<slug> origin/<base>`. slug는 이슈 제목을 영문 kebab-case로 옮긴 것(5단어 내외, 소문자). 같은 이름의 브랜치가 있으면 알리고 묻는다.
  4. 설정에 `project`가 있으면 org Project의 Status를 **In progress**로 바꾼다. 실패하면 경고만 남기고 흐름을 막지 않는다.
- 출력: 브랜치명, 분기점 SHA, 계획 코멘트 링크.

#### 4 implement — 구현

- 계획의 단계를 순서대로 수행한다. 단계마다 **구현 → 검증(계획에 적은 명령 실행) → 커밋**.
- 커밋 메시지는 프로젝트 커밋 컨벤션(CLAUDE.md)을 따른다. 검증이 실패한 상태로 커밋하지 않는다.
- 트러블슈팅·계획 변경이 생기면 이슈 코멘트로 남긴다 (draft 승인 후).
- 도메인 지식(예: spring-backend 스킬)은 description으로 자동 발화한다. 이 단계가 직접 호출하지 않는다.
- push는 하지 않는다 (7 ship에서). 사용자가 요청하면 중간 push 가능.
- 출력: 커밋 목록, 검증 결과.

#### 5 review — 리뷰 팬아웃

- diff 범위는 `origin/<base>...HEAD`. 변경 파일 목록과 특성을 분석해 `references/review-agents.md`의 선택표대로 에이전트를 고른다.
- 선택된 pr-review-toolkit 에이전트와 설정의 `reviewers`(도메인 리뷰어)를 **Agent 도구로 병렬 호출**한다. 모든 호출에 `model: <review_model>`(기본 opus)을 명시한다. inherit 에이전트가 세션 모델을 따라가지 않게 하는 유일한 방법이다.
- 각 에이전트 프롬프트에는 diff 범위, 변경 파일 목록, 이슈 요약, 확정된 범위를 담는다.
- 결과를 **치명 / 중요 / 제안 / 잘한 점**으로 합친다. 항목마다 에이전트명과 `파일:라인`을 남긴다.
- 출력: 통합 리뷰 보고서.

#### 6 apply — 리뷰 반영

- **치명·중요** 항목은 반영한다. 단, 지적이 기술적으로 타당한지 코드로 확인한 뒤 반영한다. 타당하지 않으면 근거와 함께 "반영하지 않음"으로 보고한다. 리뷰어의 말을 맹목적으로 따르지 않는다.
- **제안** 항목은 목록을 보여주고 반영할 것을 고르게 한다.
- 반영 후 검증을 다시 돌리고 커밋한다.
- 치명·중요가 남아 있으면 5 review를 다시 돌린다. **최대 3회**. 3회 후에도 남으면 목록과 함께 사용자에게 넘긴다.
- 통과 후 설정 `simplify`(기본 true)면 code-simplifier를 **한 번** 돌리고, 검증을 다시 돌린 뒤 커밋한다. 검증이 깨지면 그 변경은 되돌린다.
- 출력: 반영 내역, 미반영 사유, 최종 검증 결과.

#### 7 ship — PR

1. 전체 검증(테스트·빌드)을 한 번 더 돌린다. 실패하면 PR을 만들지 않는다.
2. 프로젝트에 `docs/history/`가 있으면 프로젝트 규칙(CLAUDE.md)에 따라 히스토리 문서를 작성·커밋한다. 규칙을 찾을 수 없으면 건너뛰고 알린다. (워크스페이스 규칙: 히스토리 작성 → PR 생성 순서)
3. `git push -u origin <branch>`.
4. PR draft를 만든다.
   - base: 판정된 base 브랜치
   - 제목: 이슈 제목 기반, 프로젝트 커밋 컨벤션의 제목 규칙을 따른다
   - 본문: 요약 / 변경 내역 / 검증 결과 / 이슈 연결. 기본은 `Closes #<n>`. 이슈 본문에 "머지 밖의 완료 조건"(심사·운영 반영 확인 등)이 명시돼 있으면 `Refs #<n>`을 쓴다.
   - assignee: `@me`
   - **게이트**: draft를 보여주고 승인 후 `gh pr create`.
5. 머지 정책: 설정 `merge`가 `auto`면 CI 통과를 기다려 `gh pr merge --<merge_method> --delete-branch`. `manual`(기본)이면 PR URL을 보고하고 멈춘다. 설정이 없고 프로젝트 CLAUDE.md에 머지 정책이 있으면 그것을 따른다. **`--squash`는 설정에 명시된 경우에만** 쓴다.
6. 머지됐으면 base로 checkout·pull, 로컬 브랜치를 삭제한다. Project Status Done 전이는 `Closes`에 의한 GitHub 자동화에 맡긴다.
- 출력: PR URL, 머지 여부, 정리 결과.

### 4.5 게이트 원칙

- **밖으로 나가는 것은 반드시 draft 확인**: 이슈 코멘트, PR, 머지. 예외 없음.
- **되돌리기 어려운 것은 하지 않는다**: force-push, base 직접 커밋, 이슈 임의 close, 설정에 없는 squash.
- **추정하지 않는다**: base·이슈·브랜치가 애매하면 후보를 보여주고 묻는다.

## 5. `review` 커맨드

```
/agentic-devflow:review                  # 현재 브랜치 diff 전체, 선택표대로
/agentic-devflow:review tests errors     # 특정 관점만
```

- 5 review → 6 apply를 현재 브랜치에서 단독 실행한다. PR에 사람 피드백이 달린 뒤 재리뷰하거나, `work` 없이 리뷰만 받을 때 쓴다.
- 관점 인자는 pr-review-toolkit의 어휘를 그대로 쓴다: `code` `tests` `errors` `comments` `types` `simplify` `all`. 익숙한 이름을 새로 만들지 않는다.
- base 판정·설정 파일 읽기는 `work`와 같은 절차(§4.2)를 공유한다. 절차 본문은 `stages/5-review.md`·`6-apply.md`를 그대로 참조하고 복제하지 않는다.

## 6. 판정 규칙 (references/)

### 6.1 base 브랜치·prefix 판정 (`base-resolution.md`)

이슈→PR 경로가 브랜치 모델에서 필요로 하는 값은 `base`와 `branch_prefix` 둘뿐이다. 이름 있는 모델은 이 두 값의 프리셋이다.

| 프리셋 | base | branch_prefix | 비고 |
|---|---|---|---|
| git-flow | `develop` | `feature/` | release·hotfix는 범위 밖 |
| github-flow | 기본 브랜치 (`main`·`master` 등) | `feature/` | 트렁크 기반 + 짧은 브랜치도 동작이 같다 |

판정 순서:

| 순서 | 근거 | 결과 |
|---|---|---|
| 1 | 설정 파일에 `base` 명시 | 그대로 |
| 2 | 프로젝트 CLAUDE.md에 워크플로우 선언 (Git Flow / GitHub Flow / base 이름) | 해당 프리셋 |
| 3 | 원격에 `develop` 존재 | git-flow 프리셋 |
| 4 | `develop` 없음 **그리고** 기본 브랜치 외에 장수 브랜치로 보이는 것(`dev` `development` `staging` `next` `release*`, 기본 브랜치가 아닌 `master`)이 없음 | github-flow 프리셋 |
| 5 | 그 외 (장수 브랜치 후보 여럿, 원격 없음) | **추정하지 않고 묻는다.** 후보 목록 제시 |

- 기본 브랜치는 `gh repo view --json defaultBranchRef`로 읽는다. 로컬 추측 금지.
- 3·4·5로 판정한 첫 실행에서는 결과를 보여주고 확인받은 뒤, `.claude/agentic-devflow.md`에 기록을 제안한다. 기록하면 다음부터 1번으로 끝난다.
- 프리셋에 없는 레포(예: base=`staging`)는 설정 파일의 `base`로 지정한다. 새 프리셋이 필요하면 이 표에 행을 추가한다.

### 6.2 리뷰 에이전트 선택 (`review-agents.md`)

pr-review-toolkit의 `review-pr` 커맨드가 하는 선택을 이 플러그인이 직접 한다. 이유: 커맨드를 통해 호출하면 `model: inherit`인 에이전트 4종의 모델을 강제할 수 없다.

| 에이전트 | 실행 조건 | 프론트매터 model |
|---|---|---|
| code-reviewer | 항상 | opus |
| pr-test-analyzer | 테스트 파일 변경, 또는 테스트 없는 신규 로직 | inherit |
| silent-failure-hunter | try/catch·에러 처리·fallback·로깅 변경 | inherit |
| type-design-analyzer | 클래스·record·interface·타입 신설·변경 | inherit |
| comment-analyzer | 주석·docstring·문서 추가·변경 | inherit |
| code-simplifier | 6 apply 통과 후 1회 (설정 `simplify`) | opus |
| 설정 `reviewers`의 도메인 리뷰어 | 항상 (지정된 경우) | 각자 |

- **모든 호출에 `model: <review_model>`을 명시**한다. 프론트매터 값과 무관하게 통일한다.
- 독립적이므로 한 메시지에서 병렬 호출한다.
- 도메인 리뷰어의 계약: Agent 도구로 호출 가능한 에이전트명, diff 범위·파일 목록을 받아 심각도별 지적을 `파일:라인`과 함께 돌려준다. kent-beck·vladimir-khorikov는 이미 이 형식이다.

## 7. 프로젝트 설정 파일 (`references/settings.md`)

경로 `.claude/agentic-devflow.md`. 레포에 체크인해 팀·에이전트가 공유한다. YAML frontmatter만 읽고 본문은 자유 메모다. **모든 키가 선택**이며, 없으면 자동 판정 또는 기본값이다.

```yaml
---
base: develop                  # 생략 시 §6.1로 판정
branch_prefix: feature/        # 기본 feature/
project: 4                     # org Project 번호. 생략 시 Status 갱신 건너뜀
reviewers:                     # 도메인 리뷰어 에이전트명. 생략 시 pr-review-toolkit만
  - spring-backend:kent-beck
  - spring-backend:vladimir-khorikov
review_model: opus             # 기본 opus
simplify: true                 # 기본 true. 리뷰 통과 후 code-simplifier 1회
merge: manual                  # manual(기본) | auto
merge_method: merge            # merge(기본) | rebase | squash
---
```

우선순위: 설정 파일 > 프로젝트 CLAUDE.md 선언 > 자동 판정/기본값. 워크스페이스 CLAUDE.md가 항상 로드되므로 커밋 컨벤션·히스토리 규칙 같은 것은 설정 파일에 중복 적지 않는다.

## 8. 오류·중단 조건

| 상황 | 동작 |
|---|---|
| git 레포 아님 / `gh` 인증 안 됨 / GitHub 원격 아님 | 사전 확인에서 중단, 이유 보고 |
| 이슈 없음 / 닫힘 | 없으면 중단. 닫혔으면 알리고 계속 여부 질문 |
| 미커밋 변경·다른 브랜치 체크아웃 상태 | 알리고 확인. 임의 stash·commit 금지 |
| 브랜치명 충돌 | 알리고 다시 묻는다 |
| `git pull`/`fetch` 실패 | 중단. 로컬 base로 조용히 진행하지 않는다 |
| 검증(테스트·빌드) 실패 | 다음 단계로 가지 않는다. 고치거나 보고 |
| Project Status 갱신 실패 | 경고만. 흐름 유지 |
| 리뷰 3회 후에도 치명·중요 잔존 | 사용자에게 넘긴다 |
| 히스토리 규칙을 못 찾음 | 건너뛰고 알린다 |

## 9. 검증 방법

플러그인은 코드가 아니라 절차 문서라 단위 테스트가 없다. 대신 아래로 검증한다.

1. **정적 검증**: `plugin-dev:plugin-validator` 에이전트로 매니페스트·디렉토리·프론트매터를 검사한다. `claude plugin validate`가 있으면 함께 돌린다.
2. **로컬 로드**: `claude --plugin-dir ./agentic-devflow`로 띄워 `/agentic-devflow:work`·`review`가 목록에 뜨고 의존성이 만족되는지 확인한다.
3. **시나리오 드라이런**: 샌드박스 레포(이 워크스페이스의 `playground` 등)에 테스트 이슈를 만들어 다음을 각각 확인한다.
   - 인자 있음 / 없음(브랜치 추론) / 없음(목록 선택)
   - base 판정 3·4·5번 경로 각각 (develop 있음 / 없음 / 장수 브랜치 여럿)
   - 재개: 브랜치만 있음 → 커밋 있음 → PR 있음 각 상태에서 재호출
   - 리뷰 팬아웃에서 모든 Agent 호출에 `model: opus`가 들어가는지
   - 밖으로 나가는 모든 동작(코멘트·PR·머지)에 draft 게이트가 걸리는지
4. **스킬 품질**: `plugin-dev:skill-reviewer`로 description 트리거 품질을 본다.

## 10. 배포

1. 이 레포 초기 커밋(스펙·골격)은 main에 직접 한다. 이후 변경은 feature 브랜치 → PR → main.
2. `.github/workflows/auto-release.yml`은 claude-plugins의 재사용 워크플로우를 쓴다 (git-flow와 동일).
3. claude-plugins 레포 `marketplace.json`에 다음을 추가하는 PR:
   - `plugins[]`에 agentic-devflow 항목 (source url + sha)
   - 루트에 `"allowCrossMarketplaceDependenciesOn": ["claude-plugins-official"]` — 없으면 설치가 `cross-marketplace` 오류로 실패한다
4. 설치: `/plugin install agentic-devflow@jeongph-claude-plugins` → pr-review-toolkit이 자동 설치·활성화된다.

## 11. 결정 기록

| 결정 | 이유 |
|---|---|
| 플러그인을 프로세스(agentic-devflow)와 도메인(spring-backend)으로 분리 | 프로세스는 도메인 무관, 지식·리뷰어는 Spring 종속. 한 플러그인이면 정체성이 두 문장이 된다 |
| git-flow에 의존하지 않음, github-flow 플러그인 없음 | 이슈→PR이 필요로 하는 건 base·prefix 두 값. 브랜치 모델별 플러그인은 잘못된 분할 축 |
| pr-review-toolkit 에이전트를 커맨드 대신 직접 호출 | inherit 에이전트 4종에 opus를 강제할 유일한 방법 |
| superpowers 의존 없음 | 불필요한 절차·토큰 증가 |
| 리뷰 완료 마커를 두지 않음 | 마커 관리 비용 > 재개 시 한 번 묻는 비용 |
| 계획·범위의 정본은 이슈 코멘트 | 워크스페이스 규칙(이슈가 단일 상태판) + compact 복원 근거 |
| `merge` 기본값 manual | 공개 플러그인의 안전 기본값. 워크스페이스는 CLAUDE.md 정책이 우선 적용된다 |
| 커맨드명 `work` | "work 146"으로 읽힌다. `issue`는 이슈 생성으로 오해될 수 있다 |

## 12. 후속 후보 (이번 범위 밖)

- release·hotfix 경로 스킬 (같은 `base-resolution.md`를 읽는다)
- 사이클 규율 지식 스킬 (compact 후 "지금 어느 단계인지"를 자동으로 안내). 지금은 `/work` 재호출로 충분
- 이슈 없이 시작하는 경로 (`work --new "제목"`으로 이슈 생성부터)
- spring-backend 플러그인: 백엔드 설계·보안·테스트 스킬 + kent-beck·vladimir-khorikov 이관·고도화
