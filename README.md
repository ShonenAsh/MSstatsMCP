# MSstatsMCP

> [!CAUTION]
> In active development, not recommended for real experiments

R MCP server implementation for MSstats family of packages

Scope: MSstats and MSstatsConvert. Label-free only for now.

## Setup

Requires R 4.6. Optional: Claude Code for testing.

```r
# in the cloned repo
install.packages("renv")
renv::restore()   # MSstats and MSstatsConvert install from GitHub devel
```

```bash
claude mcp add -s local msstats -- Rscript --no-init-file /path/to/MSstatsMCP/server.R
```

Restart Claude Code, or run `/mcp`. `--no-init-file` keeps renv's startup messages off stdout, which carries the MCP protocol.

## Design decisions

1. No data passes through the model.
2. No arbitrary R code execution (for now).
    - Models may try to reason from the output of R snippets they generated, bypassing the checked tools.
3. Tools return data handles plus a summary.
    - The summary covers dimensions, columns, replicates per condition and missingness.
4. Tools return evidence, not verdicts. 
    - Output is raw results only, such as a
   condition x batch crosstab, never `"verdict": "confounded"`. This keeps the
   model's reasoning traceable and free of assumptions baked into the server.
5. The user defines the hypothesis, assumptions and experiment details before any
   group comparison.
   - This is workflow context for the server, not a property of any
   single tool.

## Handles

A tool that creates data stores it and returns a **handle**, `<type>_<n>`, such as `raw_1` or `processed_3`. Later tools take handles as input, so data never passes through the model.

- **type:** what the object is (`raw`, `processed`). Tools reject a handle of the wrong type.
- **n:** a per-type counter that only goes up, so a number is never reused.
- **label** (optional): a name given at creation, such as `drug_vs_vehicle`.
- **source:** the tool, arguments and input handles that made the object. Following `source` back traces any result to its raw data:

```
processed_1  source: data_process(input = raw_1, normalization = equalizeMedians, ...)
raw_1        source: load_example(dataset = DDARawData)
```

`inspect_object()` lists every handle with its type, label, creation time and source. `inspect_object(handle)` adds the summary saved at creation.

## Persistence

State lives in `.msstats-mcp/` in the repo (gitignored):

```
.msstats-mcp/
├── objects/
│   ├── raw_1.rds          # the object (uncompressed, for speed)
│   ├── raw_1.meta.rds     # handle, type, label, created, source, summary
│   └── counters.rds       # last number used per type
└── logs/                  # one MSstats log per call
```

Objects are also kept in memory. Handles survive server restarts: after a restart, objects load from disk on first use. Listing reads only the `.meta.rds` files.

## Code layout

```
server.R              # entry point: activates renv, sources R/, starts the server
R/
├── registry.R        # add_tool() and msstats_tools()
├── utils.R           # stdout guard, state paths, log readers
├── store.R           # handles and persistence
└── tool-<name>.R     # one tool per file: implementation + add_tool()
```

## Tools

| Tool | Status | Returns |
|---|---|---|
| `server_info()` | done | R, MSstats and MSstatsConvert versions |
| `load_example(dataset, label)` | done | `raw` handle for a bundled MSstats dataset, plus design and missingness summary |
| `inspect_object(handle = NULL)` | done | Every handle if `NULL`, otherwise details of one |
| `data_process(input, normalization, summary_method, impute, censored_int, label)` | done | `processed` handle, plus per-protein missingness and imputation, removed features, censored values. Runs in the foreground until background jobs land. |
| `inspect_file(path)` | planned | Metadata, columns, guessed vendor format |
| `load_annotation(path)` | planned | Handle, and a table of Condition x BioReplicate x Run counts |
| `check_design(annotation, batch = NULL)` | planned | Replicates per group, paired or independent, condition x batch crosstab (or a note that batch is missing) |
| `convert(format, input, annotation, options)` | planned | MSstats-format handle, plus rows removed per filter. `format = "MSstats"` validates only. |
| `job_status(id)` | planned | Running, done (with the result) or failed (with the error) |
| `qc_plot(handle, type, proteins)` | planned | PNG image: QC, profile or condition plot |
| `build_contrast(conditions, comparisons)` | planned | Contrast matrix built from specs like `"Treated - Vehicle"`, echoed back for confirmation |
| `group_comparison(processed, contrast)` | planned | Handle, significant proteins per comparison at the given FDR, count of infinite fold changes |
| `get_results(handle, filter, sort, limit)` | planned | Filtered, sorted, paged rows |
| `model_qc_plot(handle, type)` | planned | PNG image: residual or normality plot |
| `design_sample_size(comparison, desired_fc, fdr, num_sample \| power)` | planned | Sample size or power. Needs a fitted `group_comparison`. |
| `export(handle, path)` | planned | Path of the written CSV or RDS |

Upstream bugs found along the way, with workarounds: [known-bugs.md](known-bugs.md).
