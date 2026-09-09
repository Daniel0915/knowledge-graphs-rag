# Lesson 7: Expanding the Knowledge Graph

> 학습 날짜:
> 상태: ⬜ 예정

## 이 레슨의 목표

- 외부 데이터(예: Form 13 투자 정보)를 추가해 그래프 확장
- 엔티티 간 새로운 관계(예: 회사-투자사) 연결

## 핵심 개념

### 새로운 엔티티 노드 추가
```cypher
MERGE (com:Company {cusip6: $cusip6})
ON CREATE SET com.name = $companyName
```

### 엔티티 간 관계 연결
```cypher
MATCH (com:Company), (mgr:Manager)
MERGE (mgr)-[owns:OWNS_STOCK_IN]->(com)
SET owns.value = $value, owns.shares = $shares
```

### 확장된 그래프에서 다중 홉 질의
- 벡터 검색 + 그래프 관계 탐색을 결합해 단순 텍스트 검색으로 얻기 힘든 답 도출

## 배운 점 / 인사이트

-

## 헷갈렸던 점 / 질문

-
