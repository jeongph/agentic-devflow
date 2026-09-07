# 프로젝트 설정 파일

경로는 `.claude/agentic-devflow.md`다. 레포에 체크인해 팀원과 에이전트가 같은 값을 공유한다. YAML frontmatter만 해석하고, 그 아래 본문은 자유 메모라 읽지 않는다.

**모든 키가 선택이다.** 파일이 없거나 키가 없으면 자동 판정 또는 기본값으로 동작한다.

## 스키마

| 키 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `base` | string | 자동 판정 (`references/base-resolution.md`) | 분기·PR 대상 브랜치 |
| `branch_prefix` | string | `feature/` | 작업 브랜치 접두사. 브랜치명은 `<branch_prefix><이슈번호>-<slug>` |
| `project` | number | 없음 → Project Status 갱신을 건너뛴다 | GitHub org Project 번호 |
| `reviewers` | string[] | `[]` | 도메인 리뷰어 에이전트명. `플러그인:에이전트` 형식 (예: `spring-backend:kent-beck`) |
| `review_model` | string | `opus` | 모든 리뷰 에이전트 호출에 명시할 모델 |
| `simplify` | boolean | `true` | 리뷰 통과 후 `pr-review-toolkit:code-simplifier`를 1회 돌린다 |
| `merge` | `manual` \| `auto` | `manual` | PR 생성 후 머지 여부. `auto`는 CI 통과를 기다려 머지 |
| `merge_method` | `merge` \| `rebase` \| `squash` | `merge` | `gh pr merge` 방식. `squash`는 여기 명시할 때만 쓴다 |

## 예시

```yaml
---
base: develop                  # 생략 시 자동 판정
branch_prefix: feature/        # 기본 feature/
project: 4                     # org Project 번호. 생략 시 Status 갱신 건너뜀
reviewers:                     # 도메인 리뷰어. 생략 시 pr-review-toolkit만
  - spring-backend:kent-beck
  - spring-backend:vladimir-khorikov
review_model: opus             # 기본 opus
simplify: true                 # 기본 true
merge: manual                  # manual(기본) | auto
merge_method: merge            # merge(기본) | rebase | squash
---

이 아래는 자유 메모. 플러그인은 읽지 않는다.
```

## 우선순위

```
설정 파일  >  프로젝트 CLAUDE.md 선언  >  자동 판정 / 기본값
```

- 워크스페이스·프로젝트 CLAUDE.md는 세션에 항상 로드된다. 커밋 컨벤션, 히스토리 문서 규칙, 머지 정책처럼 CLAUDE.md가 이미 담는 것은 이 파일에 중복해 적지 않는다.
- 이 파일은 CLAUDE.md가 담기 어려운 **구조화된 값**(브랜치·번호·에이전트명·불리언)만 담는다.

## 읽는 법

1. Read 도구로 `.claude/agentic-devflow.md`를 읽는다. 없으면 모든 키가 기본값이다.
2. 첫 줄이 `---`이면 다음 `---`까지를 YAML로 해석한다. frontmatter가 없으면 파일이 없는 것과 같다.
3. 표에 없는 키는 무시하되, 오타일 수 있으니 한 줄 알린다: "설정 파일의 `reviewer` 키는 인식하지 않습니다. `reviewers`를 뜻했나요?"
4. 타입이 맞지 않는 값(예: `project: "four"`)은 기본값으로 대체하고 알린다.
