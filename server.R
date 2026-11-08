# stdout carries the MCP protocol. Use message() for diagnostics, never print().

# Locate the project from the script path; the client may launch from anywhere.
file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
project <- dirname(normalizePath(sub("^--file=", "", file_arg)))

# Keep startup messages off stdout.
sink(stderr())

# renv resolves the project from the working directory.
setwd(project)
source(file.path("renv", "activate.R"))

source(file.path("R", "registry.R"))
source(file.path("R", "utils.R"))
source(file.path("R", "store.R"))
for (f in list.files("R", pattern = "^tool-.*[.]R$", full.names = TRUE)) {
  source(f)
}

suppressPackageStartupMessages({
  library(MSstats)
  library(MSstatsConvert)
})

sink()

# Run every tool here, never in the user's interactive R sessions.
mcptools::mcp_server(tools = msstats_tools(), session_tools = FALSE)
