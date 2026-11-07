# MSstatsMCP
R MCP server implementation for MSstats family of packages

Scope: MSstats and MSstatsConvert. Label-free only for now.

## Design decisions

1. No data passes through the model.
2. No arbitrary R code execution (for now).
    - Models may try to reason from the output of R snippets they generated, bypassing the checked tools.
3. Tools return data handles plus a summary.
    - The summary covers dimensions, columns, replicates per condition and missingness.
4. Tools return evidence, not verdicts. 
    - Output is raw results only, such as a
   condition × batch crosstab, never `"verdict": "confounded"`. This keeps the
   model's reasoning traceable and free of assumptions baked into the server.
5. The user defines the hypothesis, assumptions and experiment details before any
   group comparison.
   - This is workflow context for the server, not a property of any
   single tool.

## Tools

| Tool | Returns |
|---|---|
| `inspect_file(path)` | Metadata, columns, guessed vendor format |
| `inspect_object(handle = NULL)` | Every handle if `NULL`, otherwise details of one |
| `load_annotation(path)` | Handle, and a table of Condition × BioReplicate × Run counts |
| `check_design(annotation, batch = NULL)` | Replicates per group, paired or independent, condition × batch crosstab (or a note that batch is missing) |
| `convert(format, input, annotation, options)` | MSstats-format handle, plus rows removed per filter. `format = "MSstats"` validates only. |
| `data_process(input, normalization, summary_method, impute, ...)` | Job ID. When done: handle, and a missingness summary aggregated per protein across runs |
| `job_status(id)` | Running, done (with the result) or failed (with the error) |
| `qc_plot(handle, type, proteins)` | PNG image: QC, profile or condition plot |
| `build_contrast(conditions, comparisons)` | Contrast matrix built from specs like `"Treated - Vehicle"`, echoed back for confirmation |
| `group_comparison(processed, contrast)` | Handle, significant proteins per comparison at the given FDR, count of infinite fold changes |
| `get_results(handle, filter, sort, limit)` | Filtered, sorted, paged rows |
| `model_qc_plot(handle, type)` | PNG image: residual or normality plot |
| `design_sample_size(comparison, desired_fc, fdr, num_sample \| power)` | Sample size or power. Needs a fitted `group_comparison`. |
| `export(handle, path)` | Path of the written CSV or RDS |
