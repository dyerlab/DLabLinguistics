#' Deserialize a raw Float32 blob into a numeric vector
#'
#' Converts the SQLite BLOB representation of a Float32 array (little-endian,
#' as written by the Linguistics Swift package) into an R numeric vector.
#'
#' @param blob A `raw` vector — the value returned by RSQLite for a BLOB column.
#' @param dims Integer. Number of floats encoded in `blob` (`dimensions` column).
#' @return A numeric vector of length `dims`.
#' @keywords internal
decode_vector <- function(blob, dims) {
  readBin(blob, what = "numeric", n = dims, size = 4, endian = "little")
}


#' Read the documents table
#'
#' Returns every row from the `documents` table — one row per source document
#' (research paper or academic program) stored in the corpus.
#'
#' @param con A DBI connection returned by [open_corpus_store()].
#' @return A data.frame with columns `id`, `corpus_uuid`, `title`, `filename`,
#'   `doi`, and `created_at`.
#' @export
#' @examples
#' \dontrun{
#' con  <- open_corpus_store("results.sqlite")
#' docs <- read_documents(con)
#' close_corpus_store(con)
#' }
read_documents <- function(con) {
  DBI::dbReadTable(con, "documents")
}


#' Read embeddings with optional filtering
#'
#' Queries the `embeddings` table (joined to `documents` for `title` and `doi`)
#' and deserializes the binary `vector` BLOB column into a `vec` list-column of
#' numeric vectors.
#'
#' @param con A DBI connection returned by [open_corpus_store()].
#' @param provider Character or `NULL`. If supplied, only rows whose `provider`
#'   matches this value are returned.  See [provider_keys()] for valid values.
#' @param part Character or `NULL`. If supplied, only rows whose `part` matches
#'   this manuscript section are returned.  Valid values: `"Title"`,
#'   `"Abstract"`, `"Introduction"`, `"Methods"`, `"Results"`,
#'   `"Discussion"`, `"Other"`.
#' @param granularity Character or `NULL`. If supplied, only rows matching
#'   `"section"` or `"paragraph"` are returned.
#' @return A [tibble::tibble()] with all `embeddings` columns plus `title`,
#'   `doi` (from `documents`), and `vec` (deserialized numeric vector).
#'
#' @details
#' **FDL normalization:** `fdl` vectors are raw frequency counts and are **not**
#' L2-normalized by the Swift library.  Call [normalize_vectors()] on the result
#' of [embedding_matrix()] before using [cosine_similarity()] or
#' [pairwise_similarity()] with `fdl` data.
#'
#' @export
#' @examples
#' \dontrun{
#' con   <- open_corpus_store("results.sqlite")
#' intro <- read_embeddings(con, provider = "miniLM", part = "Introduction")
#' mat   <- embedding_matrix(intro)
#' close_corpus_store(con)
#' }
read_embeddings <- function(con, provider = NULL, part = NULL, granularity = NULL) {
  filters <- character(0)
  params  <- list()

  if (!is.null(provider)) {
    filters <- c(filters, "e.provider = ?")
    params  <- c(params, list(provider))
  }
  if (!is.null(part)) {
    filters <- c(filters, "e.part = ?")
    params  <- c(params, list(part))
  }
  if (!is.null(granularity)) {
    filters <- c(filters, "e.granularity = ?")
    params  <- c(params, list(granularity))
  }

  where_clause <- if (length(filters) > 0L) {
    paste("WHERE", paste(filters, collapse = " AND "))
  } else {
    ""
  }

  sql <- paste(
    "SELECT e.*, d.title, d.doi",
    "FROM embeddings e",
    "JOIN documents d ON d.id = e.document_id",
    where_clause
  )

  rows <- if (length(params) > 0L) {
    DBI::dbGetQuery(con, sql, params = params)
  } else {
    DBI::dbGetQuery(con, sql)
  }

  rows$vec <- mapply(
    decode_vector,
    rows$vector,
    rows$dimensions,
    SIMPLIFY = FALSE
  )

  tibble::as_tibble(rows)
}
