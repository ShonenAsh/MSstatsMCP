server_info_impl <- function() {
  list(
    r_version      = as.character(getRversion()),
    msstats        = as.character(packageVersion("MSstats")),
    msstatsconvert = as.character(packageVersion("MSstatsConvert")),
    working_dir    = getwd()
  )
}

add_tool("server_info", function() {
  ellmer::tool(
    server_info_impl,
    name = "server_info",
    description = paste(
      "Report the R, MSstats and MSstatsConvert versions this server runs.",
      "Call this first to confirm the server is working."
    ),
    arguments = list(),
    annotations = ellmer::tool_annotations(
      title = "Server info",
      read_only_hint = TRUE,
      open_world_hint = FALSE
    )
  )
})
