// ============================================
// Cypher 치트시트 - Knowledge Graphs for RAG
// ============================================

// --- 조회 ---
MATCH (n) RETURN n LIMIT 25;
MATCH (m:Movie {title: "The Matrix"}) RETURN m;

// --- 관계 탐색 ---
MATCH (p:Person)-[:ACTED_IN]->(m:Movie) RETURN p.name, m.title;

// --- 필터 / 집계 ---
MATCH (p:Person)-[:ACTED_IN]->(m:Movie)
RETURN p.name, count(m) AS movies ORDER BY movies DESC LIMIT 10;

// --- 생성 / upsert ---
MERGE (c:Chunk {chunkId: $chunkId})
ON CREATE SET c.text = $text, c.chunkSeqId = $seqId;

// --- 벡터 인덱스 생성 ---
CREATE VECTOR INDEX chunk_index IF NOT EXISTS
FOR (c:Chunk) ON (c.embedding)
OPTIONS { indexConfig: {
  `vector.dimensions`: 1536,
  `vector.similarity_function`: 'cosine'
}};

// --- 임베딩 저장 ---
MATCH (chunk:Chunk) WHERE chunk.embedding IS NULL
WITH chunk, genai.vector.encode(chunk.text, "OpenAI", {token: $apiKey}) AS vector
CALL db.create.setNodeVectorProperty(chunk, "embedding", vector);

// --- 벡터 유사도 검색 ---
CALL db.index.vector.queryNodes('chunk_index', 5, $questionEmbedding)
YIELD node, score
RETURN node.text, score;

// --- 관계 연결 (청크 순서) ---
MATCH (c1:Chunk), (c2:Chunk)
WHERE c1.formId = c2.formId AND c1.chunkSeqId = c2.chunkSeqId - 1
MERGE (c1)-[:NEXT]->(c2);

// --- L2: 공동 출연자 (같은 노드 변수 재사용 = 조인 조건) ---
// 관계 유일성 규칙 때문에 톰 행크스 자신은 자동 제외된다
MATCH (tom:Person {name:"Tom Hanks"})-[:ACTED_IN]->(m)<-[:ACTED_IN]-(coActors)
RETURN coActors.name, m.title;

// --- L2: 정렬 (절 순서: ORDER BY -> SKIP -> LIMIT) ---
MATCH (nineties:Movie)
WHERE nineties.released >= 1990 AND nineties.released < 2000
RETURN nineties.title AS title, nineties.released AS year
ORDER BY year DESC
LIMIT 5;

// --- L2: 관계만 삭제 (노드는 유지) ---
MATCH (emil:Person {name:"Emil Eifrem"})-[actedIn:ACTED_IN]->(movie:Movie)
DELETE actedIn;

// --- L2: 두 노드를 각각 매칭한 뒤 관계 생성 ---
MATCH (andreas:Person {name:"Andreas"}), (emil:Person {name:"Emil Eifrem"})
MERGE (andreas)-[hasRelationship:WORKS_WITH]->(emil)
RETURN andreas, hasRelationship, emil;

// --- L2: 방향 무시 조회 (화살표 없음) ---
MATCH (a:Person {name:"Andreas"})-[r]-(other) RETURN type(r), other.name;
