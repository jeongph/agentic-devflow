---
name: review
description: "현재 브랜치의 커밋된 변경(base 대비)을 리뷰 에이전트로 리뷰하고 치명·중요 항목을 반영한다. push는 하지 않는다. 관점을 지정하면 그 관점만 돌린다. 사용법: /agentic-devflow:review [관점...]"
disable-model-invocation: true
argument-hint: "[code|tests|errors|comments|types|simplify|all]"
---

# Review

현재 브랜치의 변경을 리뷰하고 반영한다. `work`의 review·apply 단계만 떼어낸 것이다.

쓰는 때:

- PR에 사람 피드백이 달려 고친 뒤, 다시 기계 리뷰를 받을 때
- `work` 없이 진행한 브랜치를 리뷰만 받을 때

인자: `$ARGUMENTS`

플러그인 루트: `${CLAUDE_PLUGIN_ROOT}`. 참조·단계 문서 안의 `references/…`·`skills/…` 경로는 모두 이 루트 기준이다.

## 원칙

`work`와 같다. 밖으로 나가는 것(이슈 코멘트·PR 코멘트)은 draft를 먼저 보여주고, 되돌리기 어려운 것은 하지 않으며, 추정하지 않는다. push는 하지 않는다.

## 사전 확인

`${CLAUDE_PLUGIN_ROOT}/references/preflight.md`를 전부 따른다. 검증 명령 확정(5항)을 포함한다. **검증 명령 없이 반영 단계로 들어가지 않는다.**

추가로:

- 현재 브랜치가 base 자신이면 중단한다: "base 브랜치(`<base>`)에 서 있습니다. 작업 브랜치에서 실행하세요."
- 미커밋 변경이 있으면 알리고 확인받는다. 리뷰 대상은 커밋된 변경(`origin/<base>...HEAD`)뿐이라 미커밋 변경은 빠진다. 포함하려면 먼저 커밋하라고 안내한다.
- 이슈 맥락: 브랜치명이 `<prefix><n>-…`면 이슈 `n`을 읽어 요약·범위(`scope` 마커 코멘트)를 프롬프트에 넣는다. 아니면 이슈 맥락 없이 diff만으로 리뷰한다.

## 관점 인자

`$ARGUMENTS`를 `${CLAUDE_PLUGIN_ROOT}/references/review-agents.md`의 "관점 인자 매핑"으로 해석한다. 비어 있으면 `all`. 인식하지 않는 인자는 알리고, 인식하는 인자가 없으면 중단한다.

## 실행

`${CLAUDE_PLUGIN_ROOT}/skills/work/stages/5-review.md` → `${CLAUDE_PLUGIN_ROOT}/skills/work/stages/6-apply.md` 순서로 따른다. 절차를 복제하지 않는다. 인자가 `simplify`뿐이면 5-review를 건너뛰고 6-apply의 정리 절차만 수행한다.

## 보고

6-apply의 출력을 그대로 보고한다: 반영 내역, 미반영 사유, 최종 검증 결과, 루프 횟수, 돌린 에이전트와 모델.

push는 하지 않는다. 사용자가 요청하면 `git push`. PR이 열려 있으면 push 후 PR에 반영 요약 코멘트를 제안한다 (draft 승인 후).
