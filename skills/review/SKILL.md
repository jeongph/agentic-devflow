---
name: review
description: "현재 브랜치의 변경(base 대비)을 pr-review-toolkit 에이전트(opus)와 프로젝트 도메인 리뷰어로 리뷰하고 치명·중요 항목을 반영한다. 사용법: /agentic-devflow:review [code|tests|errors|comments|types|simplify|all]"
disable-model-invocation: true
argument-hint: "[aspects]"
---

# Review

현재 브랜치의 변경을 리뷰하고 반영한다. `work`의 5·6단계만 떼어낸 것이다.

쓰는 때:

- PR에 사람 피드백이 달려 고친 뒤, 다시 기계 리뷰를 받을 때
- `work` 없이 진행한 브랜치를 리뷰만 받을 때

인자: `$ARGUMENTS`

## 사전 확인

`skills/work/SKILL.md`의 "1. 사전 확인"과 같다. git 레포·gh 인증·GitHub 원격을 확인하고, 설정 파일(`references/settings.md`)을 읽고, base를 판정한다(`references/base-resolution.md`).

추가로:

- 현재 브랜치가 base 자신이면 중단한다: "base 브랜치(develop)에 서 있습니다. 작업 브랜치에서 실행하세요."
- 미커밋 변경이 있으면 알린다. 리뷰 대상은 커밋된 변경(`origin/<base>...HEAD`)이므로 미커밋 변경은 빠진다. 포함하려면 먼저 커밋하라고 안내한다.

## 관점 인자

`$ARGUMENTS`를 `references/review-agents.md`의 "관점 인자 매핑"으로 해석한다. 비어 있으면 `all`.

이슈 맥락: 브랜치명이 `<branch_prefix><n>-…`면 이슈 `n`을 읽어 요약·범위를 프롬프트에 넣는다. 아니면 이슈 맥락 없이 diff만으로 리뷰한다.

## 실행

`skills/work/stages/5-review.md` → `skills/work/stages/6-apply.md` 순서로 따른다. 절차를 복제하지 않는다.

## 보고

6-apply의 출력을 그대로 보고한다: 반영 내역, 미반영 사유, 최종 검증 결과, 루프 횟수.

push는 하지 않는다. 사용자가 요청하면 `git push`. PR이 열려 있으면 push 후 PR에 반영 요약 코멘트를 제안한다 (draft 승인 후).
