# Lesson 3: Preparing Text Data for RAG

> 학습 날짜: 2026-09-13
> 상태: ✅ 완료
> 실습 노트북: [L3-prep_text_for_RAG.ipynb](L3-prep_text_for_RAG.ipynb)

## 이 레슨의 목표

- Neo4j에 **벡터 인덱스(Vector Index)** 를 생성한다
- 텍스트 속성(`Movie.tagline`)을 임베딩해 노드의 속성으로 저장한다
- 질문 임베딩과의 **유사도 검색(similarity search)** 으로 영화를 찾는다

> 지금까지(L2)는 `MATCH`로 **정확히 일치하는 값**을 찾았다면,
> 이번 레슨은 **의미가 비슷한 것**을 찾는다. RAG의 검색 단계에 해당한다.

## 전체 흐름

```
1. 벡터 인덱스 생성        CREATE VECTOR INDEX
2. 텍스트 → 임베딩 → 노드에 저장   genai.vector.encode + setNodeVectorProperty
3. 질문 → 임베딩 → 유사도 검색     db.index.vector.queryNodes
```

## 셋업

L2와 거의 같지만 **OpenAI 키가 추가**된다.

```python
from dotenv import load_dotenv
import os
from langchain_community.graphs import Neo4jGraph

import warnings
warnings.filterwarnings("ignore")

load_dotenv('.env', override=True)
NEO4J_URI = os.getenv('NEO4J_URI')
NEO4J_USERNAME = os.getenv('NEO4J_USERNAME')
NEO4J_PASSWORD = os.getenv('NEO4J_PASSWORD')
NEO4J_DATABASE = os.getenv('NEO4J_DATABASE')
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')

# 이 강의 환경 전용 - 본인 환경에서 실행할 때는 제거
OPENAI_ENDPOINT = os.getenv('OPENAI_BASE_URL') + '/embeddings'

kg = Neo4jGraph(
    url=NEO4J_URI, username=NEO4J_USERNAME,
    password=NEO4J_PASSWORD, database=NEO4J_DATABASE
)
```

> `OPENAI_ENDPOINT`는 강의 환경이 프록시를 쓰기 때문에 필요한 것.
> 실제 OpenAI를 직접 호출한다면 `endpoint` 파라미터 없이 `token`만 넘기면 된다.

## 1. 벡터 인덱스 생성

```cypher
CREATE VECTOR INDEX movie_tagline_embeddings IF NOT EXISTS
FOR (m:Movie) ON (m.taglineEmbedding)
OPTIONS { indexConfig: {
  `vector.dimensions`: 1536,
  `vector.similarity_function`: 'cosine'
}}
```

| 요소 | 의미 |
|---|---|
| `movie_tagline_embeddings` | 인덱스 이름. 나중에 검색할 때 이 이름으로 지목한다 |
| `FOR (m:Movie) ON (m.taglineEmbedding)` | `Movie` 라벨의 `taglineEmbedding` 속성에 인덱스를 건다 |
| `vector.dimensions: 1536` | OpenAI `text-embedding-ada-002`의 차원 수. **모델과 반드시 일치해야 한다** |
| `vector.similarity_function: 'cosine'` | 유사도 계산 방식 (`cosine` 또는 `euclidean`) |

- `IF NOT EXISTS` 덕분에 셀을 여러 번 실행해도 안전 (L2의 `MERGE`와 같은 멱등 개념)
- 백틱(`` ` ``)은 키 이름에 `.`이 들어가서 필요한 것
- 인덱스는 **틀(scheme)만 만드는 것**이다. 이 시점엔 아직 값이 하나도 없다

확인:

```cypher
SHOW VECTOR INDEXES
```

## 2. 벡터 인덱스 채우기 (임베딩 생성 + 저장)

```cypher
MATCH (movie:Movie) WHERE movie.tagline IS NOT NULL
WITH movie, genai.vector.encode(
    movie.tagline,
    "OpenAI",
    {
      token: $openAiApiKey,
      endpoint: $openAiEndpoint
    }) AS vector
CALL db.create.setNodeVectorProperty(movie, "taglineEmbedding", vector)
```

```python
params={"openAiApiKey": OPENAI_API_KEY, "openAiEndpoint": OPENAI_ENDPOINT}
```

한 줄씩:

- `WHERE movie.tagline IS NOT NULL` — tagline이 없는 영화는 임베딩할 것이 없으므로 제외
- `genai.vector.encode(텍스트, 공급자, 설정)` — **Neo4j가 직접 OpenAI API를 호출**해서 임베딩을 받아온다.
  파이썬에서 임베딩을 만들어 넣는 게 아니라 DB 안에서 처리된다는 점이 포인트
- `WITH movie, ... AS vector` — 다음 절로 `movie`와 `vector`를 넘긴다.
  `WITH`는 쿼리를 단계로 나누는 파이프 같은 것
- `CALL db.create.setNodeVectorProperty(...)` — 만들어진 벡터를 노드 속성으로 저장.
  벡터는 일반 `SET`이 아니라 **전용 프로시저**로 저장해야 인덱스가 인식한다

> `$openAiApiKey`처럼 **파라미터로 넘기는 이유**: 쿼리 문자열에 키를 직접 박으면
> 노트북과 git에 그대로 노출된다. 파라미터화하면 값이 분리된다.

### 저장 결과 확인

```python
result = kg.query("""
    MATCH (m:Movie)
    WHERE m.tagline IS NOT NULL
    RETURN m.tagline, m.taglineEmbedding
    LIMIT 1
    """)

result[0]['m.tagline']                  # 원본 텍스트
result[0]['m.taglineEmbedding'][:10]    # 벡터 앞 10개 값만
len(result[0]['m.taglineEmbedding'])    # 1536
```

길이가 **1536**으로 나오는 것이 인덱스 생성 시 지정한 `vector.dimensions`와 일치.
이 숫자가 어긋나면 검색이 동작하지 않는다.

## 3. 유사도 검색

```python
question = "What movies are about love?"
```

```cypher
WITH genai.vector.encode(
    $question,
    "OpenAI",
    {
      token: $openAiApiKey,
      endpoint: $openAiEndpoint
    }) AS question_embedding
CALL db.index.vector.queryNodes(
    'movie_tagline_embeddings',
    $top_k,
    question_embedding
    ) YIELD node AS movie, score
RETURN movie.title, movie.tagline, score
```

```python
params={"openAiApiKey": OPENAI_API_KEY,
        "openAiEndpoint": OPENAI_ENDPOINT,
        "question": question,
        "top_k": 5}
```

핵심은 **저장할 때와 똑같은 방식으로 질문도 임베딩**한다는 것.
같은 모델로 만든 벡터끼리여야 거리 비교가 의미를 가진다.

- `WITH ... AS question_embedding` — `MATCH` 없이 `WITH`로 시작한다.
  그래프를 훑는 게 아니라 값 하나를 계산해서 다음 단계로 넘기는 것
- `db.index.vector.queryNodes(인덱스명, top_k, 질문벡터)` — 가장 가까운 `top_k`개 노드를 반환
- `YIELD node AS movie, score` — 프로시저의 반환값을 받는다.
  `YIELD`는 `CALL` 전용으로, 프로시저가 내보내는 컬럼을 꺼내 쓰는 문법
- `score` — 코사인 유사도. **1에 가까울수록 유사**하고, 결과는 score 내림차순으로 정렬되어 나온다

### 직접 해보기

```python
question = "What movies are about adventure?"
```

질문만 바꿔 같은 쿼리를 돌리면 다른 영화들이 나온다.
tagline에 "adventure"라는 단어가 없어도 **의미가 비슷하면 걸린다**는 게 키워드 검색과의 차이.

## 배운 점 / 인사이트

- **벡터 검색이 그래프 안에서 일어난다**는 게 이 강의의 핵심 구도다.
  보통 RAG는 벡터 DB를 따로 두는데, 여기서는 노드의 속성으로 임베딩을 들고 있으니
  유사도로 노드를 찾은 뒤 **그 노드에서 관계를 타고 확장**할 수 있다 (= Graph RAG)
- 임베딩 생성을 파이썬이 아니라 Cypher 안에서(`genai.vector.encode`) 처리한다.
  데이터를 DB 밖으로 꺼냈다 넣는 왕복이 없다
- L2의 `MATCH (m:Movie {title:"Cloud Atlas"})`는 **정확히 일치**해야 찾지만,
  벡터 검색은 **가까운 것**을 찾는다. 이 둘은 대체 관계가 아니라 조합해서 쓰는 것
- 차원 수(1536)는 인덱스 정의와 임베딩 모델 양쪽에서 일치해야 하는 계약 같은 값

## 헷갈렸던 점 / 질문

### Q. `WITH`가 정확히 뭘 하는 건가?

쿼리를 **단계로 나누는 파이프**다. 앞 절의 결과 중 뒤에서 쓸 것만 골라 넘긴다.

- 2번 쿼리: `WITH movie, vector` → `movie`와 계산된 `vector`를 다음 `CALL`로 전달
- 3번 쿼리: `MATCH` 없이 `WITH`로 시작 → 값 하나만 계산해서 넘기는 용도

`WITH`에서 언급하지 않은 변수는 이후 절에서 쓸 수 없다.

### Q. `CALL`과 `YIELD`는?

`CALL`은 Neo4j에 내장된 **프로시저(procedure)** 를 호출하는 문법이고,
`YIELD`는 그 프로시저가 반환하는 컬럼을 꺼내 변수에 바인딩한다.

| 프로시저 | 역할 |
|---|---|
| `db.create.setNodeVectorProperty(node, 속성명, 벡터)` | 벡터를 노드 속성으로 저장 |
| `db.index.vector.queryNodes(인덱스명, k, 벡터)` | 유사한 노드 상위 k개 조회 → `node`, `score` 반환 |

### Q. 왜 벡터는 그냥 `SET`으로 저장하지 않나?

벡터는 내부적으로 일반 리스트 속성과 다르게 취급된다.
`db.create.setNodeVectorProperty`를 써야 벡터 인덱스가 제대로 인식한다.

### Q. `score`는 높을수록 좋은 건가?

`cosine`을 썼으므로 **1에 가까울수록 유사**하다.
결과는 이미 유사도 내림차순으로 정렬되어 나오므로 별도 `ORDER BY`가 필요 없다.

## 다음 레슨과의 연결

이번엔 이미 존재하는 `Movie` 노드의 tagline을 임베딩했다.
다음 레슨(L4)은 **원문 텍스트를 청크로 나눠 그래프 자체를 새로 구성**하는 단계로 넘어간다.

## 참고

- 강의: [Preparing Text Data for RAG](https://learn.deeplearning.ai/courses/knowledge-graphs-rag)
- [Neo4j Vector Indexes](https://neo4j.com/docs/cypher-manual/current/indexes/semantic-indexes/vector-indexes/)
- [genai.vector.encode()](https://neo4j.com/docs/cypher-manual/current/genai-integrations/)
