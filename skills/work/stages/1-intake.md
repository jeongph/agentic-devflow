# 1. intake — 이슈 확인

## 입력

- 이슈 번호 `n`
- `owner/repo` (사전 확인)

## 절차

1. 이슈를 통째로 읽는다. 상위·하위 이슈도 같은 호출로 가져온다.
   ```bash
   gh issue view <n> --json number,title,body,state,labels,assignees,url,comments,parent,subIssues
   ```
   본문과 **코멘트 전체**를 읽는다. 이전 세션이 남긴 분석·범위·계획(마커 `<!-- agentic-devflow:… -->`)이 여기 있다. 같은 마커가 여러 개면 가장 최근 것이 정본이다.

2. 호출이 실패하면 원인으로 나눈다.
   - `parent`·`subIssues` 필드를 모른다는 오류(구버전 gh·GHES)면 두 필드를 빼고 다시 호출하고, 출력의 `관계` 줄에 "조회 불가 (sub-issue 미지원)"를 적는다.
   - 인증·네트워크·레이트 리밋·`Could not resolve to an Issue`면 **중단**한다. 사전 확인이 중단 사유로 삼는 것과 같은 종류다. 이슈 번호가 틀렸다는 가장 이른 신호이기도 하다.

3. `state`가 `CLOSED`면 알리고 계속할지 묻는다. 닫힌 이슈에 작업을 얹는 것은 대개 실수다.

4. 중복 후보를 찾는다. 제목의 핵심어 2~3개로 검색하고 `n` 자신은 제외한다.
   ```bash
   gh issue list --state open --search "<핵심어>" --json number,title --limit 10
   ```
   있으면 알리기만 한다. 닫거나 라벨을 붙이지 않는다 (사람이 판단할 일).

5. 선례를 찾는다. `docs/history/_INDEX.md`가 있으면 핵심어로 `grep`해 3건 이내로 추려 읽는다. 인덱스 전체를 읽지 않는다.
   ```bash
   grep -i "<핵심어>" docs/history/_INDEX.md | head -5
   ```

## 게이트

읽기 전용 단계라 승인 게이트는 없다. 단, 이슈가 닫혀 있을 때 "계속할까요?" 한 번.

## 출력

`이슈 요약`:

```
#146 주문 취소 시 재고 복원   [Feature] · backend · open · assignee: 없음
무엇을     주문 취소 API 호출 시 해당 주문 라인의 재고를 원복한다
왜         현재는 취소해도 재고가 줄어든 채 남아 품절 오판 발생 (본문 + 코멘트 #2 분석)
관계       상위 #140 [Epic] 주문 도메인 정합성 · 하위 없음        ← 조회 못 했으면 "조회 불가 (사유)"
기존 분석  코멘트 #2: 원인은 CancelService가 StockService를 호출하지 않음
선례       2026-07-02 재고 차감 동시성 보호 (docs/history/…)
중복 후보  없음
```

`관계` 줄은 "없음"과 "조회 불가"를 구분해 적는다. 사용자가 읽는 것은 이 화면이지 중간에 흘린 경고가 아니다.
