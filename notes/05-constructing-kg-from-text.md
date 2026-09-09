# Lesson 5: Constructing a Knowledge Graph from Text Documents

> 학습 날짜:
> 상태: ⬜ 예정

## 이 레슨의 목표

- 실제 문서(예: SEC 공시자료)로부터 그래프 구성
- 청크 노드 생성 및 임베딩 저장

## 핵심 개념

### 문서 → 청크 노드
- 문서를 파싱해 `:Chunk` 노드로 저장
- 메타데이터(출처, 순번 등)를 속성으로 부여

### 임베딩 계산 & 저장
```cypher
MATCH (chunk:Chunk) WHERE chunk.embedding IS NULL
WITH chunk, genai.vector.encode(chunk.text, "OpenAI", {token: $apiKey}) AS vector
CALL db.create.setNodeVectorProperty(chunk, "embedding", vector)
```

### 벡터 검색으로 관련 청크 찾기
```cypher
CALL db.index.vector.queryNodes('chunk_index', 5, $question_embedding)
YIELD node, score
RETURN node.text, score
```

## 배운 점 / 인사이트

-

## 헷갈렸던 점 / 질문

-
