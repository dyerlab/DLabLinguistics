# Linguistics SQLite Output — R Package Overview

This document describes the SQLite database produced by the `Linguistics` Swift library so that an R package can consume it for downstream statistical analysis of text embeddings.

---

## What the Swift library produces

The CLI pipeline converts research paper PDFs into embedding vectors and saves them in a SQLite file (e.g., `results.sqlite`). The typical workflow is:

```
PDF files
  → convert_pdfs.py (marker)       # PDF → Markdown
  → ManuscriptLoader               # Markdown → Corpus (section/paragraph chunks)
  → MultiProviderEmbedder          # embed chunks with multiple models
  → CorpusStore.write([Corpus])    # persist to SQLite
```

The output is a single self-contained `.sqlite` file that can be placed anywhere R can read it.

---

## Database schema

Two tables. All string columns use UTF-8. No foreign key enforcement is enabled (SQLite default).

### `documents`

One row per source document (research paper or academic program).

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK | Auto-increment row identifier |
| `corpus_uuid` | TEXT | UUID string — stable identity of the `Corpus` object (`Corpus.id`) |
| `title` | TEXT | Document title (first level-1 Markdown heading, or filename) |
| `filename` | TEXT | Source `.md` filename (e.g., `smith2024.md`) |
| `doi` | TEXT | DOI extracted from first 3 000 chars, if present (e.g., `10.1038/s41586-024-00001-x`) |
| `created_at` | TEXT | ISO-8601 timestamp when the row was written |

### `embeddings`

One row per embedded chunk. Multiple rows per document (one per section/paragraph × provider).

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK | Auto-increment row identifier |
| `document_id` | INTEGER | Foreign key → `documents.id` |
| `part` | TEXT | Manuscript section (`Title`, `Abstract`, `Introduction`, `Methods`, `Results`, `Discussion`, `Other`) |
| `granularity` | TEXT | `section` or `paragraph` |
| `provider` | TEXT | Embedding model identifier (see table below) |
| `dimensions` | INTEGER | Vector length (number of floats) |
| `vector` | BLOB | Raw little-endian `Float32` array — `dimensions × 4` bytes |
| `scaling` | REAL | Weight/scaling factor (default `1.0`; `Credits` value for academic programs) |
| `source_text` | TEXT | The exact text that was embedded |

---

## Provider identifier values

The `provider` column contains one of these string keys:

| `provider` | Model | Typical `dimensions` |
|------------|-------|----------------------|
| `nl` | Apple NLEmbedding (word vectors, avg pooling) | ~300 (macOS 26+) |
| `fdl` | FDL frequency-count bag-of-words | vocab size (variable per corpus) |
| `miniLM` | MiniLM sentence transformer | 384 |
| `bgeBase` | BGE Base | 768 |
| `bgeLarge` | BGE Large | 1024 |
| `mxbaiEmbedLarge` | mxbai-embed-large-v1 | 1024 |
| `qwen3Embedding` | Qwen3 (4-bit quantized) | varies |
| `nomicTextV1_5` | Nomic Embed Text v1.5 (Matryoshka) | varies |
| `custom:<hub-id>` | Any HuggingFace Hub model | varies |

**Normalization notes:**
- `nl`, `miniLM`, `bge*`, `mxbai*`, `qwen3*`, `nomic*` vectors are **L2-normalized** (unit length) — cosine similarity = dot product.
- `fdl` vectors are **raw frequency counts, NOT normalized**. Compute cosine similarity manually (normalize first) or use Euclidean distance. The `dimensions` value equals the vocabulary size built from the full corpus, which varies per run.

---

## Vector deserialization in R

```r
library(RSQLite)

con <- dbConnect(SQLite(), "results.sqlite")

# Read embeddings table (vector column is a raw list of blobs)
emb <- dbReadTable(con, "embeddings")

# Deserialize one vector
decode_vector <- function(blob, dims) {
  readBin(blob, what = "numeric", n = dims, size = 4, endian = "little")
}

# Add decoded vectors as a list-column
emb$vec <- mapply(decode_vector, emb$vector, emb$dimensions, SIMPLIFY = FALSE)

# Example: build a matrix of all Introduction vectors from one provider
intro_nl <- subset(emb, part == "Introduction" & provider == "nl")
vec_matrix <- do.call(rbind, intro_nl$vec)  # rows = chunks, cols = dimensions

dbDisconnect(con)
```

---

## Typical query patterns

### Get all documents with their section counts

```r
dbGetQuery(con, "
  SELECT d.title, d.doi, e.provider, e.part, COUNT(*) AS n_chunks
  FROM documents d
  JOIN embeddings e ON e.document_id = d.id
  GROUP BY d.id, e.provider, e.part
  ORDER BY d.title, e.provider, e.part
")
```

### Load embeddings for one provider and section type

```r
rows <- dbGetQuery(con, "
  SELECT e.*, d.title, d.doi
  FROM embeddings e
  JOIN documents d ON d.id = e.document_id
  WHERE e.provider = 'miniLM'
    AND e.part     = 'Introduction'
    AND e.granularity = 'section'
")
rows$vec <- mapply(decode_vector, rows$vector, rows$dimensions, SIMPLIFY = FALSE)
```

### Compare two providers on the same chunks

```r
# Get document_ids and part combos present in both providers
both <- dbGetQuery(con, "
  SELECT a.document_id, a.part, a.source_text,
         a.vector AS vec_nl, a.dimensions AS dims_nl,
         b.vector AS vec_mini, b.dimensions AS dims_mini
  FROM embeddings a
  JOIN embeddings b
    ON  a.document_id = b.document_id
    AND a.part        = b.part
    AND a.granularity = b.granularity
  WHERE a.provider = 'nl'
    AND b.provider = 'miniLM'
")
```

---

## Recommended R package structure

The R package wrapping this (suggested name: `linguisticsR` or `embeddings`) should expose:

| Function | Purpose |
|----------|---------|
| `open_corpus_store(path)` | Opens connection, returns a connection object |
| `read_documents(con)` | Returns a data.frame of the `documents` table |
| `read_embeddings(con, provider=NULL, part=NULL, granularity=NULL)` | Filtered read with automatic vector deserialization; returns a tibble with a `vec` list-column |
| `embedding_matrix(emb_df)` | Converts the `vec` list-column to a numeric matrix (rows = chunks) |
| `cosine_similarity(a, b)` | Dot product of two unit vectors (or full matrix × matrix) |
| `pairwise_similarity(mat)` | All-pairs cosine similarity matrix |
| `provider_keys()` | Returns the known provider key strings |
| `close_corpus_store(con)` | Wraps `dbDisconnect` |

### Dependencies to consider

- `RSQLite` — SQLite driver (required)
- `DBI` — database interface abstraction (required)
- `tibble` — for list-column support in the return type
- `Matrix` — sparse matrix support (useful for FDL vectors which are often sparse)

### FDL-specific handling

FDL vectors are raw frequency counts and variable-length (vocabulary changes between runs). The R package should:
1. Detect `provider == "fdl"` and warn if cosine similarity is requested without normalization
2. Provide `normalize_vectors(mat)` that L2-normalizes each row
3. Note that FDL vectors from different `CorpusStore` files are **not comparable** unless built from the same vocabulary (same set of documents)

---

## Example end-to-end R session

```r
library(linguisticsR)  # the package being built

con <- open_corpus_store("~/research/results.sqlite")

# Overview
docs <- read_documents(con)
cat(nrow(docs), "documents in store\n")

# Load miniLM Introduction embeddings
intro <- read_embeddings(con, provider = "miniLM", part = "Introduction")
mat   <- embedding_matrix(intro)        # n_docs × 384 matrix

# Pairwise cosine similarity between all Introduction sections
sim <- pairwise_similarity(mat)         # n_docs × n_docs matrix
rownames(sim) <- intro$title

# Cluster
hc <- hclust(as.dist(1 - sim), method = "ward.D2")
plot(hc, main = "Document similarity (miniLM · Introduction)")

close_corpus_store(con)
```

---

## File locations

| File | Purpose |
|------|---------|
| `/Volumes/Developer/Swift/Linguistics/Sources/Linguistics/Models/CorpusStore.swift` | SQLite writer/reader — authoritative schema definition |
| `/Volumes/Developer/Swift/Linguistics/Sources/Linguistics/Embeddings/MultiProviderEmbedder.swift` | Multi-provider runner |
| `/Volumes/Developer/Swift/Linguistics/convert_pdfs.py` | PDF → Markdown batch converter |
| `/Volumes/Developer/Swift/Linguistics/Sources/Linguistics/Loaders/ManuscriptParts.swift` | `part` column value definitions |
| `/Volumes/Developer/Swift/Linguistics/Sources/Linguistics/Types/EmbeddingGranularity.swift` | `granularity` column value definitions |
