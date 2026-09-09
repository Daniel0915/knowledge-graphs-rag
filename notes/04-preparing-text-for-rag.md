# Lesson 4: Preparing Text Data for RAG

> 학습 날짜:
> 상태: ⬜ 예정

## 이 레슨의 목표

- 텍스트를 청크(chunk)로 분할하는 이유와 방법
- 임베딩(embedding) 생성과 벡터 인덱스 개념

## 핵심 개념

### 텍스트 청킹 (Chunking)
- 긴 문서를 검색/임베딩 단위로 분할
- chunk size, overlap 설정의 트레이드오프

### 임베딩 (Embedding)
- 텍스트를 벡터로 변환 (예: OpenAI `text-embedding-ada-002`)
- 의미적 유사도를 벡터 거리로 계산

### Neo4j 벡터 인덱스
```cypher
CREATE VECTOR INDEX <name> IF NOT EXISTS
FOR (c:Chunk) ON (c.embedding)
OPTIONS { indexConfig: {
  `vector.dimensions`: 1536,
  `vector.similarity_function`: 'cosine'
}}
```

## 배운 점 / 인사이트

-

## 헷갈렸던 점 / 질문

-
