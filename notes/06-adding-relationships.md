# Lesson 6: Adding Relationships to the Knowledge Graph

> 학습 날짜:
> 상태: ⬜ 예정

## 이 레슨의 목표

- 청크 간, 청크-문서 간 관계 연결
- 관계를 활용해 문맥(context) 확장

## 핵심 개념

### 청크 순서 관계 (NEXT)
```cypher
MATCH (c1:Chunk), (c2:Chunk)
WHERE c1.formId = c2.formId AND c1.chunkSeqId = c2.chunkSeqId - 1
MERGE (c1)-[:NEXT]->(c2)
```

### 문서-청크 관계 (PART_OF)
```cypher
MATCH (c:Chunk), (f:Form)
WHERE c.formId = f.formId
MERGE (c)-[:PART_OF]->(f)
```

### 관계를 활용한 컨텍스트 윈도우 확장
- 벡터 검색으로 찾은 청크의 앞뒤 청크(`:NEXT`)를 함께 가져와 답변 품질 향상

## 배운 점 / 인사이트

-

## 헷갈렸던 점 / 질문

-
