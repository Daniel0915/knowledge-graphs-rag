# Lesson 3: Querying Knowledge Graphs with Cypher

> 학습 날짜:
> 상태: ⬜ 예정

## 이 레슨의 목표

- Cypher 기본 문법으로 그래프 조회/생성/수정
- 패턴 매칭으로 관계 탐색

## 핵심 개념

### MATCH — 패턴 매칭 조회
```cypher
MATCH (m:Movie {title: "The Matrix"})
RETURN m
```

### 관계 탐색
```cypher
MATCH (p:Person)-[:ACTED_IN]->(m:Movie)
WHERE m.title = "The Matrix"
RETURN p.name
```

### 집계 / 정렬
```cypher
MATCH (p:Person)-[:ACTED_IN]->(m:Movie)
RETURN p.name, count(m) AS movies
ORDER BY movies DESC
LIMIT 10
```

### CREATE / MERGE
- `CREATE`: 무조건 새로 생성
- `MERGE`: 있으면 매칭, 없으면 생성 (upsert)

## 배운 점 / 인사이트

-

## 헷갈렸던 점 / 질문

-
