#' Open a corpus store SQLite database
#'
#' Opens a connection to a `.sqlite` file produced by the Linguistics Swift
#' package.  Pass the returned connection to [read_documents()],
#' [read_embeddings()], and related functions, then close it with
#' [close_corpus_store()] when done.
#'
#' @param path Character. Path to the `.sqlite` file.
#' @return A DBI connection object (class `"SQLiteConnection"`).
#' @seealso [close_corpus_store()], [read_documents()], [read_embeddings()]
#' @export
#' @examples
#' \dontrun{
#' con <- open_corpus_store("~/research/results.sqlite")
#' docs <- read_documents(con)
#' close_corpus_store(con)
#' }
open_corpus_store <- function(path) {
  if (!file.exists(path)) {
    stop("Corpus store not found: ", path)
  }
  DBI::dbConnect(RSQLite::SQLite(), path)
}


#' Close a corpus store connection
#'
#' Wrapper around [DBI::dbDisconnect()] that accepts connections created by
#' [open_corpus_store()].
#'
#' @param con A DBI connection returned by [open_corpus_store()].
#' @return Invisibly `TRUE`.
#' @export
close_corpus_store <- function(con) {
  DBI::dbDisconnect(con)
  invisible(TRUE)
}
