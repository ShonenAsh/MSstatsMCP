# Known bugs

Bugs found in upstream packages while building MSstatsMCP. Each one names its workaround here.

Checked against MSstats `c4d4b77` (4.21.1) and MSstatsConvert `3955a02` (1.23.6).

## MSstatsConvert

### 1. An explicit log path with `append = FALSE` keeps only the last log line

**Where:** `R/utils_logging.R:29-35` (`.fileAppender`), called at line 114.

**What happens:** `append` is passed to every `cat()` call, not only the first. Each log line overwrites the file.

**Reproduce:**
```r
dataProcess(DDARawData, log_file_path = "f.log", append = FALSE, verbose = FALSE)
length(readLines("f.log"))   # 1: "== Summarization is done."
dataProcess(DDARawData, log_file_path = "t.log", append = TRUE, verbose = FALSE)
length(readLines("t.log"))   # 31
```

**Who is affected:** anyone who sets `log_file_path` and keeps the default `append = FALSE`. That covers every MSstats function that logs: `dataProcess`, `groupComparison`, and the converters. The default (no path) is unaffected, because line 119 calls `.fileAppender()` with its own default, `append = TRUE`.

**Expected:** per `@param append` ("If TRUE, information about data processing will be added to an existing log file"), `append = FALSE` should clear the file once at the start of the run, then add each line to it.

**Possible fix:** in `.fileAppender`, run `if (!append) file.create(log_file_path)` once when the logger is created, and always write lines with `append = TRUE`.

**Workaround in MSstatsMCP:** always pass `append = TRUE` with a new unique path.

### 2. Console logging writes to stdout

**Where:** `R/utils_logging.R:41-43` (`.consoleAppender`).

**What happens:** with `verbose = TRUE`, log messages are written with `cat()` to stdout instead of `message()` to stderr. Callers can't silence them with `suppressMessages()`, and they get mixed into output that `capture.output()` collects or that a protocol owns.

**Workaround in MSstatsMCP:** always pass `verbose = FALSE`, and run every call inside `with_stdout_to_stderr()`.

## MSstats

### 3. Progress bars ignore `verbose = FALSE`

**Where:**
- `R/dataProcess.R:253` and `:264` (`MSstatsSummarizeWithSingleCore`)
- `R/utils_groupcomparison.R:511` (`.groupComparisonWithSingleCore`)

**What happens:** `txtProgressBar` prints to stdout on every call, whatever `verbose` is set to. `verbose = FALSE` doesn't make `dataProcess` or `groupComparison` quiet.

**Expected:** no progress bar when `verbose = FALSE`.

**Workaround in MSstatsMCP:** `with_stdout_to_stderr()` in `R/utils.R`.

## mcptools (1.0.3)

### 4. The server `instructions` text can't be configured

**Where:** `R/server.R:760`.

**What happens:** every server sends the hardcoded instructions "This provides information about a running R session." `mcp_server()` has no argument to override them.

**Impact:** MSstatsMCP can't use server instructions to set the analysis workflow (design review, diagnostics, claims audit).

**Workaround:** none yet. Options: put the guidance in tool descriptions, add a guide tool, or patch upstream.
