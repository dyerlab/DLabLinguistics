#' Known embedding provider keys
#'
#' Returns the embedding provider identifiers used in the `provider` column of
#' the `embeddings` table.  Custom HuggingFace Hub models are stored with the
#' prefix `"custom:<hub-id>"` and are not enumerated here.
#'
#' @details
#' Normalization status:
#' * **L2-normalized** (cosine similarity = dot product): `nl`, `miniLM`,
#'   `bgeBase`, `bgeLarge`, `mxbaiEmbedLarge`, `qwen3Embedding`,
#'   `nomicTextV1_5`.
#' * **NOT normalized** (raw frequency counts): `fdl` — call
#'   [normalize_vectors()] before computing cosine similarity.
#'
#' @return A named character vector mapping provider key strings to short
#'   model descriptions.
#' @export
#' @examples
#' provider_keys()
#' names(provider_keys())   # just the key strings
provider_keys <- function() {
  c(
    nl              = "Apple NLEmbedding — word vectors, avg pooling (~300-dim, macOS 26+)",
    fdl             = "FDL frequency-count bag-of-words (variable dim; NOT L2-normalized)",
    miniLM          = "MiniLM sentence transformer (384-dim, L2-normalized)",
    bgeBase         = "BGE Base (768-dim, L2-normalized)",
    bgeLarge        = "BGE Large (1024-dim, L2-normalized)",
    mxbaiEmbedLarge = "mxbai-embed-large-v1 (1024-dim, L2-normalized)",
    qwen3Embedding  = "Qwen3 4-bit quantized (variable dim, L2-normalized)",
    nomicTextV1_5   = "Nomic Embed Text v1.5 Matryoshka (variable dim, L2-normalized)"
  )
}
