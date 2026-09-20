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

// --- L3: 벡터 인덱스 생성 (차원 수는 임베딩 모델과 일치해야 함) ---
CREATE VECTOR INDEX movie_tagline_embeddings IF NOT EXISTS
FOR (m:Movie) ON (m.taglineEmbedding)
OPTIONS { indexConfig: {
  `vector.dimensions`: 1536,
  `vector.similarity_function`: 'cosine'
}};

SHOW VECTOR INDEXES;

// --- L3: 텍스트 임베딩 후 노드 속성으로 저장 ---
MATCH (movie:Movie) WHERE movie.tagline IS NOT NULL
WITH movie, genai.vector.encode(
    movie.tagline, "OpenAI",
    {token: $openAiApiKey, endpoint: $openAiEndpoint}) AS vector
CALL db.create.setNodeVectorProperty(movie, "taglineEmbedding", vector);

// --- L3: 질문 임베딩 -> 유사도 검색 (score는 1에 가까울수록 유사) ---
WITH genai.vector.encode(
    $question, "OpenAI",
    {token: $openAiApiKey, endpoint: $openAiEndpoint}) AS question_embedding
CALL db.index.vector.queryNodes(
    'movie_tagline_embeddings', $top_k, question_embedding
    ) YIELD node AS movie, score
RETURN movie.title, movie.tagline, score;

// --- L4: 청크 노드 upsert (chunkId를 고유 키로, 생성 시에만 속성 채움) ---
MERGE (mergedChunk:Chunk {chunkId: $chunkParam.chunkId})
    ON CREATE SET
        mergedChunk.names = $chunkParam.names,
        mergedChunk.formId = $chunkParam.formId,
        mergedChunk.cik = $chunkParam.cik,
        mergedChunk.cusip6 = $chunkParam.cusip6,
        mergedChunk.source = $chunkParam.source,
        mergedChunk.f10kItem = $chunkParam.f10kItem,
        mergedChunk.chunkSeqId = $chunkParam.chunkSeqId,
        mergedChunk.text = $chunkParam.text
RETURN mergedChunk;

// --- L4: 유니크 제약 (중복 청크 방지 + 조회 속도 향상) ---
CREATE CONSTRAINT unique_chunk IF NOT EXISTS
    FOR (c:Chunk) REQUIRE c.chunkId IS UNIQUE;

SHOW INDEXES;

// --- L4: 아직 임베딩 없는 청크만 채우기 (재실행 시 비용 절약) ---
MATCH (chunk:Chunk) WHERE chunk.textEmbedding IS NULL
WITH chunk, genai.vector.encode(
  chunk.text, "OpenAI",
  {token: $openAiApiKey, endpoint: $openAiEndpoint}) AS vector
CALL db.create.setNodeVectorProperty(chunk, "textEmbedding", vector);

// --- L5: map projection - 노드에서 지정 속성만 뽑아 map으로 ---
MATCH (anyChunk:Chunk)
WITH anyChunk LIMIT 1
RETURN anyChunk { .names, .source, .formId, .cik, .cusip6 } AS formInfo;

// --- L5: 섹션별 청크를 순서대로 모아 NEXT로 연결 (APOC) ---
MATCH (from_same_section:Chunk)
WHERE from_same_section.formId = $formIdParam
  AND from_same_section.f10kItem = $f10kItemParam
WITH from_same_section
  ORDER BY from_same_section.chunkSeqId ASC
WITH collect(from_same_section) AS section_chunk_list
  CALL apoc.nodes.link(section_chunk_list, "NEXT", {avoidDuplicates: true})
RETURN size(section_chunk_list);

// --- L5: 속성 값이 같은 노드끼리 관계 연결 ---
MATCH (c:Chunk), (f:Form)
  WHERE c.formId = f.formId
MERGE (c)-[newRelationship:PART_OF]->(f)
RETURN count(newRelationship);

// --- L5: 관계에 속성 붙이기 (각 섹션의 첫 청크로 가는 지름길) ---
MATCH (first:Chunk), (f:Form)
WHERE first.formId = f.formId AND first.chunkSeqId = 0
WITH first, f
  MERGE (f)-[r:SECTION {f10kItem: first.f10kItem}]->(first)
RETURN count(r);

// --- L5: 경로(path)를 변수로 - length()는 관계 개수 ---
MATCH window = (c1:Chunk)-[:NEXT]->(c2:Chunk)-[:NEXT]->(c3:Chunk)
  WHERE c1.chunkId = $chunkIdParam
RETURN length(window) AS windowPathLength, nodes(window) AS chunkList;

// --- L5: 가변 길이 패턴 *0..1 - 경계(첫/마지막 청크)에서도 매칭 성공 ---
MATCH window = (:Chunk)-[:NEXT*0..1]->(c:Chunk)-[:NEXT*0..1]->(:Chunk)
  WHERE c.chunkId = $chunkIdParam
WITH window AS longestChunkWindow
  ORDER BY length(window) DESC LIMIT 1
RETURN length(longestChunkWindow);

// --- L5: retrieval_query - 벡터 검색 결과를 윈도우로 확장 ---
// LangChain 규약상 text, score, metadata 세 컬럼을 반환해야 한다
MATCH window = (:Chunk)-[:NEXT*0..1]->(node)-[:NEXT*0..1]->(:Chunk)
WITH node, score, window AS longestWindow
  ORDER BY length(window) DESC LIMIT 1
WITH nodes(longestWindow) AS chunkList, node, score
  UNWIND chunkList AS chunkRows
WITH collect(chunkRows.text) AS textList, node, score
RETURN apoc.text.join(textList, " \n ") AS text, score, node {.source} AS metadata;

// --- L6: 공통 식별자로 서로 다른 출처의 데이터 연결 ---
MATCH (com:Company), (form:Form)
  WHERE com.cusip6 = form.cusip6
MERGE (com)-[:FILED]->(form);

// --- L6: 전문 검색(fulltext) 인덱스 - 고유명사는 임베딩보다 이쪽 ---
CREATE FULLTEXT INDEX fullTextManagerNames
  IF NOT EXISTS
  FOR (mgr:Manager) ON EACH [mgr.managerName];

CALL db.index.fulltext.queryNodes("fullTextManagerNames", "royal bank")
  YIELD node, score
RETURN node.managerName, score;

// --- L6: 관계 속성을 MERGE 키로 (분기가 다르면 별개 관계) ---
// CSV는 모든 값이 문자열이므로 toFloat/toInteger 형변환이 필요하다
MATCH (mgr:Manager {managerCik: $ownsParam.managerCik}),
      (com:Company {cusip6: $ownsParam.cusip6})
MERGE (mgr)-[owns:OWNS_STOCK_IN {
    reportCalendarOrQuarter: $ownsParam.reportCalendarOrQuarter
}]->(com)
ON CREATE
    SET owns.value  = toFloat($ownsParam.value),
        owns.shares = toInteger($ownsParam.shares);

// --- L6: 청크에서 여러 홉 떨어진 정보까지 탐색 ---
MATCH (:Chunk {chunkId: $chunkIdParam})-[:PART_OF]->(f:Form),
      (com:Company)-[:FILED]->(f),
      (mgr:Manager)-[:OWNS_STOCK_IN]->(com)
RETURN com.companyName, count(mgr.managerName) AS numberOfinvestors;

// --- L6: 그래프 데이터를 LLM이 읽을 문장으로 번역 ---
MATCH (:Chunk {chunkId: $chunkIdParam})-[:PART_OF]->(f:Form),
      (com:Company)-[:FILED]->(f),
      (mgr:Manager)-[owns:OWNS_STOCK_IN]->(com)
RETURN mgr.managerName + " owns " + owns.shares +
    " shares of " + com.companyName +
    " at a value of $" + apoc.number.format(toInteger(owns.value)) AS text
LIMIT 10;

// --- L6: retrieval_query - 문서 밖 정보를 문맥에 주입 ---
MATCH (node)-[:PART_OF]->(f:Form),
    (f)<-[:FILED]-(com:Company),
    (com)<-[owns:OWNS_STOCK_IN]-(mgr:Manager)
WITH node, score, mgr, owns, com
    ORDER BY owns.shares DESC LIMIT 10
WITH collect(
    mgr.managerName + " owns " + owns.shares +
    " shares in " + com.companyName +
    " at a value of $" + apoc.number.format(toInteger(owns.value)) + "."
) AS investment_statements, node, score
RETURN apoc.text.join(investment_statements, "\n") + "\n" + node.text AS text,
    score,
    { source: node.source } AS metadata;
