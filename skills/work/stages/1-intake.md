# 1. intake — 이슈 확인

## 입력

- 이슈 번호 `n`
- 레포 `owner/repo` (`gh repo view --json nameWithOwner`)

## 절차

1. 이슈를 통째로 읽는다.
   ```bash
   gh issue view <n> --json number,title,body,state,labels,assignees,url,comments
   ```
   본문과 **코멘트 전체**를 읽는다. 이전 세션이 남긴 분석·범위·계획(마커 `<!-- agentic-devflow:… -->`)이 여기 있다.

2. 상위·하위 이슈를 조회한다. 실패(필드 미지원·권한)하면 건너뛰고 한 줄 알린다.
   ```bash
   gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){issue(number:$n){parent{number title state} subIssues(first:50){nodes{number title state}}}}}' -F o=<owner> -F r=<repo> -F n=<n>
   ```

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
관계       상위 #140 [Epic] 주문 도메인 정합성 · 하위 없음
기존 분석  코멘트 #2: 원인은 CancelService가 StockService를 호출하지 않음
선례       2026-07-02 재고 차감 동시성 보호 (docs/history/…)
중복 후보  없음
```
