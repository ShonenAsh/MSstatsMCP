# MSstats prints progress bars to stdout, which would break the MCP protocol.
with_stdout_to_stderr <- function(expr) {
  sink(stderr())
  on.exit(sink(), add = TRUE)
  force(expr)
}

state_dir <- function(...) {
  path <- file.path(getwd(), ".msstats-mcp", ...)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}

# tempfile() adds a random suffix, so calls in the same second never share a file.
new_log_path <- function(prefix) {
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  tempfile(paste0(prefix, "_", stamp, "_"), state_dir("logs"), ".log")
}

log_warnings <- function(path) {
  if (!file.exists(path)) {
    return(character(0))
  }
  lines <- readLines(path, warn = FALSE)
  trimws(grep("^(WARN|ERROR)", lines, value = TRUE))
}

log_censoring_cutoff <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }
  hit <- grep("intensities under cutoff =", readLines(path, warn = FALSE),
              value = TRUE)
  if (!length(hit)) {
    return(NULL)
  }
  as.numeric(sub(".*cutoff = *([-0-9.eE]+).*", "\\1", hit[length(hit)]))
}
