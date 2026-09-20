# Knowledge Graphs for RAG 학습 정리

[DeepLearning.AI - Knowledge Graphs for RAG](https://www.deeplearning.ai/courses/knowledge-graphs-rag) 강의를 학습하며 정리한 내용입니다.

> Neo4j와 협업한 강의로, 지식 그래프(Knowledge Graph)를 활용해 RAG(Retrieval Augmented Generation)의 검색 품질을 높이는 방법을 다룹니다.

## 강의 개요

- **강사**: Andreas Kollegger (Neo4j)
- **핵심 도구**: Neo4j (그래프 DB), Cypher (쿼리 언어), LangChain, OpenAI Embeddings
- **목표**: 텍스트 문서로부터 지식 그래프를 구축하고, 벡터 검색 + 그래프 탐색을 결합한 RAG 파이프라인을 만든다.

## 커리큘럼 & 진행 상황

| # | 레슨 | 정리 노트 | 상태 |
|---|------|-----------|------|
| 1 | Introduction | - | ⬜ |
| 2 | Knowledge Graph Fundamentals | [노트](notes/01-kg-fundamentals/01-kg-fundamentals.md) | ✅ |
| 3 | Querying Knowledge Graphs with Cypher | [노트](<notes/02-Querying Knowledge Graphs/02-Querying Knowledge Graphs.md>) | ✅ |
| 4 | Preparing Text Data for RAG | [노트](<notes/03-Preparing Text for RAG/03-Preparing Text for RAG.md>) | ✅ |
| 5 | Constructing a Knowledge Graph from Text | [노트](<notes/04-constructing-a-knowledge-graph-from-text-documents/04-constructing-a-knowledge-graph-from-text-documents.md>) | ✅ |
| 6 | Adding Relationships to the Knowledge Graph | [노트](<notes/05-adding-relationships-to-the-sec-knowledge-graph/05-adding-relationships-to-the-sec-knowledge-graph.md>) | ✅ |
| 7 | Expanding the Knowledge Graph | [노트](notes/07-expanding-the-kg.md) | ⬜ |
| 8 | Chatting with the Knowledge Graph | [노트](notes/08-chatting-with-the-kg.md) | ⬜ |

> 상태: ⬜ 예정 / 🟡 진행중 / ✅ 완료

## 폴더 구조

```
knowledge-graphs-rag/
├── README.md          # 이 파일 (전체 인덱스)
├── notes/             # 레슨별 학습 정리 노트
├── code/              # 실습 코드 (Python)
└── cypher/            # Cypher 쿼리 모음
```

## 핵심 개념 요약 (학습하며 채워나가기)

- **Knowledge Graph**: 노드(엔티티)와 관계(엣지)로 지식을 표현하는 구조
- **Cypher**: Neo4j의 그래프 쿼리 언어 (`MATCH`, `CREATE`, `MERGE` 등)
- **Vector Index**: 임베딩 기반 유사도 검색을 그래프 위에서 수행
- **Graph RAG**: 벡터 검색으로 찾은 노드에서 그래프 관계를 따라 확장 검색

## 참고 링크

- [강의 페이지](https://www.deeplearning.ai/courses/knowledge-graphs-rag)
- [Neo4j Cypher Manual](https://neo4j.com/docs/cypher-manual/current/)
- [LangChain Neo4j 통합](https://python.langchain.com/docs/integrations/graphs/neo4j_cypher/)
