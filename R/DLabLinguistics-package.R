#' DLabLinguistics: Analysis of Text Embeddings from the Linguistics Swift Package
#'
#' Provides tools to read and analyse the SQLite output produced by the
#' [Linguistics Swift package](https://github.com/dyerlab/Linguistics).  The
#' database contains research-paper chunks embedded with multiple neural and
#' statistical models.  This package handles the binary vector deserialisation,
#' database connection lifecycle, and common linear-algebra operations (cosine
#' similarity, L2 normalisation) needed for downstream statistical analysis.
#'
#' ## Typical workflow
#'
#' ```r
#' library(DLabLinguistics)
#'
#' con   <- open_corpus_store("~/research/results.sqlite")
#' docs  <- read_documents(con)
#' intro <- read_embeddings(con, provider = "miniLM", part = "Introduction")
#' mat   <- embedding_matrix(intro)
#' sim   <- pairwise_similarity(mat)
#' rownames(sim) <- intro$title
#' hc    <- hclust(as.dist(1 - sim), method = "ward.D2")
#' plot(hc)
#' close_corpus_store(con)
#' ```
#'
#' @keywords internal
"_PACKAGE"
