# Lesson 8: Chatting with the Knowledge Graph

> 학습 날짜:
> 상태: ⬜ 예정

## 이 레슨의 목표

- LangChain + Neo4j로 대화형 RAG 파이프라인 구성
- 벡터 검색 결과 + 그래프 컨텍스트를 LLM에 전달

## 핵심 개념

### Neo4j Vector Store (LangChain)
```python
from langchain_community.vectorstores import Neo4jVector
from langchain_openai import OpenAIEmbeddings

vector_store = Neo4jVector.from_existing_index(
    embedding=OpenAIEmbeddings(),
    url=NEO4J_URI, username=NEO4J_USERNAME, password=NEO4J_PASSWORD,
    index_name="chunk_index",
    text_node_property="text",
    retrieval_query=RETRIEVAL_QUERY,  # 그래프 관계 확장 쿼리
)
```

### Retrieval Query로 그래프 컨텍스트 주입
- 벡터로 찾은 노드에서 `:NEXT`, `:PART_OF` 등 관계를 따라 추가 컨텍스트 수집

### RetrievalQA 체인
```python
from langchain.chains import RetrievalQA
from langchain_openai import ChatOpenAI

chain = RetrievalQA.from_chain_type(
    ChatOpenAI(temperature=0),
    retriever=vector_store.as_retriever()
)
chain.invoke({"query": "질문 내용"})
```

## 배운 점 / 인사이트

-

## 헷갈렸던 점 / 질문

-

## 강의 전체 회고

-
