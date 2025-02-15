#' Find a sequence in another sequence
#'
#' @param .seq_find The sequence you want to find in another sequence
#' @param .seq_base The sequence to be searched
#'
#' @return An integer vector (vector has length zero if sequence is not found)
# # Find an integer sequence
# find_seq_in_seq(2:10, c(1:20, 1:20))
#
# # Find a character sequence
# find_seq_in_seq(c("C", "D"), LETTERS)
#
# # No sequence found
# find_seq_in_seq(c("R", "D"), LETTERS)

find_seq_in_seq <- function(.seq_find, .seq_base) {
  w <- seq_along(.seq_base)

  for (i in seq_along(.seq_find)) {
    w <- w[.seq_base[w + i - 1L] == .seq_find[i]]
    if (length(w) == 0) return(integer(0))
  }

  w <- w[!is.na(w)]
  return(w)
}

#' Helper Function for position_count()
#'
#' @param .row_terms A one row Dataframe prepared by prep_termlist()
#' @param .doc A tokenized Dataframe prepared by prep_document()
#'
#' @return A Dataframe
# DEBUG
# .row_terms <- lst_t_[[1]]
# .doc <- tab_d_
h_position_count <- function(.row_terms, .doc) {
  # Define Variables --------------------------------------------------------
  start <- tid <- ngram <- token <- check <- NULL

  vec_t_ <- unlist(.row_terms[["token"]])
  tab_d_ <- .doc
  len_t_ <- length(vec_t_)

  if (len_t_== 1) {
    tab_pos_ <- tibble::tibble(
      start = which(tab_d_[["token"]] == vec_t_)
    )
  } else {
    tab_pos_ <- tibble::tibble(
      start = find_seq_in_seq(vec_t_, tab_d_[["token"]])
    )
  }

  tab_pos_ %>%
    dplyr::mutate(
      tid   = .row_terms[["tid"]],
      stop  = start + len_t_ - 1L,
      ngram = len_t_,
    ) %>% dplyr::select(tid, ngram, start, stop) %>%
    dplyr::left_join(
      y  = dplyr::mutate(tab_d_, merging_id = dplyr::row_number()),
      by = c("start" = "merging_id")) %>%
    dplyr::select(-token)
}


#' Helper Function: Prepare termlist
#'
#' @param .tab A Dataframe with a column 'term'
#' @param .fun_std standardization function
#'
#' @return A Datframe
h_prep_termlist <- function(.tab, .fun_std = NULL) {



  # Define Variables --------------------------------------------------------
  token <- tid <- ngram <- term_orig <- oid <- term <- n_dup <- NULL

  # Check Columns in Dataframe ----------------------------------------------
  if (!"term" %in% colnames(.tab)) {
    stop("Input MUST contain the column 'term'", call. = FALSE)
  }

  # Standardize Terms -------------------------------------------------------
  if (!is.null(.fun_std)) {
    tab_ <- dplyr::mutate(.tab, term_orig = term, term = .fun_std(term))
  } else {
    tab_ <- dplyr::mutate(.tab, term_orig = term)
  }


  # Check if Terms are unique -----------------------------------------------
  if (any(duplicated(tab_[["term"]]))) {
    stop(
      "AFTER standardization, the column 'term' contains duplicates,
      please call the function check_termlist() for more information.",
      call. = FALSE
    )
  }

  # Prepare Termlist --------------------------------------------------------
  tab_ %>%
    dplyr::mutate(
      token = stringi::stri_split_fixed(term, " "),
      tid   = purrr::map_chr(term, ~ digest::digest(.x, algo = "xxhash32")),
      oid   = purrr::map(token, ~ seq_len(length(.x))),
      ngram = lengths(token)
    ) %>%
    dplyr::select(tid, ngram, term_orig, term, oid, token)

}


#' Helper Function: Get Term Dependencies
#'
#' @param .termlist A Datframe produced by h_prep_termlist()
#'
#' @return A Dataframe
h_dependencies_termlist <- function(.termlist) {
  tid <- token <- oid <- sep <- start <- pos <- tok_id <- tid_ <-
    child_pos <- NULL

  doc_ <- .termlist %>%
    dplyr::select(sep = tid, token, oid) %>%
    tidyr::unnest(c(oid, token)) %>%
    # Columns to use the position_count() function
    dplyr::mutate(tok_id = dplyr::row_number(), doc_id = 1)

  cnt_ <- position_count(.termlist, doc_, sep) %>%
    dplyr::mutate(pos = purrr::map2(start, stop, ~ .x:.y)) %>%
    dplyr::select(tid, pos) %>%
    tidyr::unnest(pos) %>%
    dplyr::left_join(dplyr::select(doc_, tid_ = sep, pos = tok_id, oid), by = "pos") %>%
    dplyr::filter(!tid == tid_) %>%
    dplyr::group_by(tid_, tid) %>%
    dplyr::summarise(child_pos = list(oid), .groups = "drop") %>%
    dplyr::group_by(tid_) %>%
    dplyr::summarise(
      child_tid = list(tid),
      child_pos = list(child_pos),
      .groups = "drop"
    )

  dplyr::left_join(.termlist, cnt_, by = c("tid" = "tid_"))

}
