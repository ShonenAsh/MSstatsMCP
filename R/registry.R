# Each R/tool-*.R file registers itself with add_tool(). `tool` is a function
# so ellmer::tool() runs at server start, not at source time.

.msstats_tools <- list()

add_tool <- function(name, tool) {
  stopifnot(is.character(name), length(name) == 1, is.function(tool))
  if (name %in% names(.msstats_tools)) {
    stop("Tool names must be unique: ", name)
  }
  .msstats_tools[[name]] <<- tool
  invisible(tool)
}

msstats_tools <- function() {
  unname(lapply(.msstats_tools, function(make_tool) make_tool()))
}
