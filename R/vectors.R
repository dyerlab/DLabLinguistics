#' Convert a list-column of embedding vectors to a matrix
#'
#' Stacks the `vec` list-column from a tibble returned by [read_embeddings()]
#' into a plain numeric matrix suitable for distance or similarity calculations.
#'
#' @param emb_df A tibble returned by [read_embeddings()], containing a `vec`
#'   list-column.
#' @return A numeric matrix with `nrow(emb_df)` rows and `dimensions` columns.
#' @export
#' @examples
#' \dontrun{
#' con  <- open_corpus_store("results.sqlite")
#' emb  <- read_embeddings(con, provider = "miniLM", part = "Abstract")
#' mat  <- embedding_matrix(emb)   # n_chunks × 384
#' close_corpus_store(con)
#' }
embedding_matrix <- function(emb_df) {
  do.call(rbind, emb_df$vec)
}


#' Cosine similarity between two vectors or two matrices
#'
#' Computes cosine similarity. For L2-normalized providers (`nl`, `miniLM`,
#' `bge*`, `mxbai*`, `qwen3*`, `nomic*`) cosine similarity equals the dot
#' product; the function normalizes anyway so unnormalized input is handled
#' correctly.  For `fdl` embeddings, consider calling [normalize_vectors()]
#' first.
#'
#' @param a A numeric vector or matrix (rows = observations).
#' @param b A numeric vector or matrix (rows = observations) with the same
#'   number of dimensions as `a`.
#' @return
#'   * A scalar when both `a` and `b` are vectors.
#'   * A matrix of size `nrow(a) × nrow(b)` when both are matrices.
#' @export
#' @examples
#' a <- c(1, 0, 0)
#' b <- c(0, 1, 0)
#' cosine_similarity(a, b)   # 0
#'
#' cosine_similarity(a, a)   # 1
cosine_similarity <- function(a, b) {
  if (is.vector(a) && is.vector(b)) {
    sum(a * b) / (sqrt(sum(a^2)) * sqrt(sum(b^2)))
  } else {
    a_norm <- a / sqrt(rowSums(a^2))
    b_norm <- b / sqrt(rowSums(b^2))
    a_norm %*% t(b_norm)
  }
}


#' All-pairs cosine similarity matrix
#'
#' Computes the symmetric cosine similarity matrix for every pair of rows in
#' `mat`.  Rows are L2-normalized before multiplication, so raw or pre-
#' normalized input both work.
#'
#' @param mat A numeric matrix with one row per embedding chunk.
#' @return A symmetric numeric matrix of size `nrow(mat) × nrow(mat)` with
#'   values in `[-1, 1]`.
#' @export
#' @examples
#' \dontrun{
#' con <- open_corpus_store("results.sqlite")
#' emb <- read_embeddings(con, provider = "miniLM", part = "Introduction")
#' mat <- embedding_matrix(emb)
#' sim <- pairwise_similarity(mat)
#' rownames(sim) <- emb$title
#' hc  <- hclust(as.dist(1 - sim), method = "ward.D2")
#' plot(hc)
#' close_corpus_store(con)
#' }
pairwise_similarity <- function(mat) {
  norms    <- sqrt(rowSums(mat^2))
  mat_norm <- mat / norms
  mat_norm %*% t(mat_norm)
}


#' L2-normalize rows of a matrix
#'
#' Scales each row of `mat` to unit length.  Required before computing cosine
#' similarity on `fdl` (frequency-count) embeddings, which are stored as raw
#' counts and are **not** normalized by the Linguistics Swift library.
#'
#' @param mat A numeric matrix with one row per embedding chunk.
#' @return A matrix of the same dimensions with each row scaled to unit
#'   Euclidean length.
#' @export
normalize_vectors <- function(mat) {
  norms <- sqrt(rowSums(mat^2))
  mat / norms
}
