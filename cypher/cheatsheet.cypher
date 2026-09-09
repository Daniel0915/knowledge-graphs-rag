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
