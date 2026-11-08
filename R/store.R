# Objects are kept in memory and on disk. Listing reads only <handle>.meta.rds.

.store <- new.env()

store_dir <- function() state_dir("objects")

store_path <- function(handle, suffix = ".rds") {
  file.path(store_dir(), paste0(handle, suffix))
}

# Handles come from the model and end up in file paths; reject anything else.
check_handle <- function(handle) {
  if (!is.character(handle) || length(handle) != 1 ||
      !grepl("^[a-z]+_[0-9]+$", handle)) {
    stop("Invalid handle: '", handle, "'. Handles look like raw_1.")
  }
}

# Counters only go up, so a handle number is never reused.
next_handle <- function(type) {
  path <- file.path(store_dir(), "counters.rds")
  counters <- if (file.exists(path)) readRDS(path) else list()
  files <- list.files(store_dir(), pattern = paste0("^", type, "_[0-9]+[.]rds$"))
  on_disk <- as.integer(sub(".*_([0-9]+)[.]rds$", "\\1", files))
  n <- max(c(0L, counters[[type]], on_disk)) + 1L
  counters[[type]] <- n
  saveRDS(counters, path)
  paste0(type, "_", n)
}

check_label <- function(label) {
  if (is.null(label)) {
    return(invisible())
  }
  if (!is.character(label) || length(label) != 1 || nchar(label) > 60) {
    stop("label must be a single string of at most 60 characters.")
  }
}

store_put <- function(object, type, source, summary = NULL, label = NULL) {
  check_label(label)
  handle <- next_handle(type)
  meta <- list(
    handle = handle,
    type = type,
    label = label,
    created = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    source = source,
    summary = summary
  )
  saveRDS(object, store_path(handle), compress = FALSE)
  saveRDS(meta, store_path(handle, ".meta.rds"))
  assign(handle, list(meta = meta, object = object), envir = .store)
  handle
}

label_arg <- function() {
  ellmer::type_string(
    paste(
      "Optional name for the result, up to 60 characters, such as",
      "drug_vs_vehicle. Shown next to the handle in inspect_object."
    ),
    required = FALSE
  )
}

store_meta <- function(handle) {
  check_handle(handle)
  if (exists(handle, envir = .store, inherits = FALSE)) {
    return(get(handle, envir = .store)$meta)
  }
  path <- store_path(handle, ".meta.rds")
  if (!file.exists(path)) {
    available <- vapply(store_list(), `[[`, "", "handle")
    stop("Handle '", handle, "' not found. Available: ",
         if (length(available)) paste(available, collapse = ", ") else "none")
  }
  readRDS(path)
}

store_get <- function(handle, type = NULL) {
  meta <- store_meta(handle)
  if (!is.null(type) && meta$type != type) {
    stop("Handle '", handle, "' is ", meta$type, ", but this needs ", type, ".")
  }
  if (!exists(handle, envir = .store, inherits = FALSE)) {
    assign(handle, list(meta = meta, object = readRDS(store_path(handle))),
           envir = .store)
  }
  get(handle, envir = .store)$object
}

store_list <- function() {
  files <- list.files(store_dir(), pattern = "[.]meta[.]rds$", full.names = TRUE)
  type <- sub("_[0-9]+[.]meta[.]rds$", "", basename(files))
  id <- as.integer(sub(".*_([0-9]+)[.]meta[.]rds$", "\\1", basename(files)))
  files <- files[order(type, id)]
  lapply(files, function(f) {
    meta <- readRDS(f)
    meta[intersect(c("handle", "type", "label", "created", "source"), names(meta))]
  })
}
