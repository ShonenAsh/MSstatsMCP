data_process_impl <- function(input,
                              normalization = "equalizeMedians",
                              summary_method = "TMP",
                              impute = TRUE,
                              censored_int = "NA",
                              label = NULL) {
  raw <- store_get(input, type = "raw")
  settings <- list(
    normalization = normalization,
    summary_method = summary_method,
    impute = impute,
    censored_int = censored_int
  )

  log_path <- new_log_path("dataProcess")
  out <- with_stdout_to_stderr(
    MSstats::dataProcess(
      raw,
      normalization = if (normalization == "none") FALSE else normalization,
      summaryMethod = summary_method,
      MBimpute = impute,
      censoredInt = censored_int,
      use_log_file = TRUE,
      log_file_path = log_path,
      append = TRUE,
      verbose = FALSE
    )
  )

  summary <- summarize_processed(out, log_censoring_cutoff(log_path))
  handle <- store_put(
    out,
    type = "processed",
    source = list(tool = "data_process", input = input, args = settings),
    summary = summary,
    label = label
  )

  list(
    handle = handle,
    label = label,
    input = input,
    settings = settings,
    summary = summary,
    log = list(path = log_path, warnings = log_warnings(log_path))
  )
}

summarize_processed <- function(out, censoring_cutoff = NULL,
                                max_proteins = 30, worst_n = 10) {
  prot <- out$ProteinLevelData
  feat <- out$FeatureLevelData

  proteins <- unique(as.character(prot$Protein))
  runs <- unique(as.character(feat$originalRUN))
  present <- unique(paste(prot$Protein, prot$originalRUN, sep = "\r"))
  expected <- as.vector(outer(proteins, runs, paste, sep = "\r"))
  absent <- setdiff(expected, present)
  absent_pairs <- if (length(absent)) {
    parts <- do.call(rbind, strsplit(absent, "\r", fixed = TRUE))
    data.frame(protein = parts[, 1], run = parts[, 2])
  } else {
    data.frame(protein = character(0), run = character(0))
  }

  features_per_protein <- tapply(as.character(feat$FEATURE),
                                 as.character(feat$PROTEIN),
                                 function(x) length(unique(x)))

  per_protein <- do.call(rbind, lapply(split(prot, as.character(prot$Protein)),
    function(p) {
      id <- as.character(p$Protein[1])
      cells <- features_per_protein[[id]] * length(runs)
      data.frame(
        protein = id,
        runs_with_value = sum(!is.na(p$LogIntensities)),
        missing_pct_mean = round(mean(p$MissingPercentage, na.rm = TRUE), 3),
        imputed_share = round(sum(p$NumImputedFeature, na.rm = TRUE) / cells, 3),
        runs_more50missing = sum(p$more50missing, na.rm = TRUE)
      )
    }))
  rownames(per_protein) <- NULL
  per_protein <- per_protein[order(-per_protein$missing_pct_mean), ]

  protein_block <- if (nrow(per_protein) <= max_proteins) {
    list(table = per_protein)
  } else {
    list(
      missing_pct_quantiles = as.list(round(quantile(
        per_protein$missing_pct_mean, c(0, .25, .5, .75, .9, 1)), 3)),
      worst = head(per_protein, worst_n),
      note = sprintf("%d proteins; showing the %d with the most missing values",
                     nrow(per_protein), worst_n)
    )
  }

  removed_row <- feat$remove %in% TRUE
  censored <- feat$censored %in% TRUE & !removed_row
  observed <- !is.na(feat$INTENSITY)

  list(
    summary_method = out$SummaryMethod,
    protein_rows = nrow(prot),
    expected_rows = length(expected),
    absent_protein_run_pairs = absent_pairs,
    per_protein = protein_block,
    features = list(
      total = length(unique(as.character(feat$FEATURE))),
      removed = length(unique(as.character(feat$FEATURE[removed_row])))
    ),
    # Kept features only. Censored values are imputed when impute = TRUE.
    censored = list(
      missing = sum(censored & !observed),
      observed_below_cutoff = sum(censored & observed),
      cutoff_log2 = censoring_cutoff
    )
  )
}

add_tool("data_process", function() {
  ellmer::tool(
    data_process_impl,
    name = "data_process",
    description = paste(
      "Run MSstats dataProcess on a raw handle: log-transform, normalize,",
      "impute censored values, and summarize feature intensities into one",
      "abundance value per protein per run.",
      "Returns a handle of type processed, plus a summary, never the data:",
      "protein-run pairs with no summarized value, per-protein missingness and",
      "imputation, features removed, censored values in kept features, and",
      "MSstats log warnings."
    ),
    arguments = list(
      input = ellmer::type_string(
        "Handle of type raw, from load_example. Example: raw_1."
      ),
      normalization = ellmer::type_enum(
        paste(
          "How runs are made comparable.",
          "equalizeMedians (default): shifts each run so median intensities",
          "match; assumes most proteins do not change between conditions.",
          "quantile: forces identical intensity distributions across runs.",
          "globalStandards: uses named reference proteins; not supported here yet.",
          "none: no normalization."
        ),
        values = c("equalizeMedians", "quantile", "none"),
        required = FALSE
      ),
      summary_method = ellmer::type_enum(
        paste(
          "How a protein's features combine into one value per run.",
          "TMP (default): Tukey median polish, robust to outlier features.",
          "linear: linear mixed model summarization."
        ),
        values = c("TMP", "linear"),
        required = FALSE
      ),
      impute = ellmer::type_boolean(
        paste(
          "Impute censored values (default true). Censored: missing, or below",
          "a cutoff MSstats computes from the data. Assumes censoring is due",
          "to the detection limit."
        ),
        required = FALSE
      ),
      censored_int = ellmer::type_enum(
        "How missing intensities are encoded. NA (default) or 0.",
        values = c("NA", "0"),
        required = FALSE
      ),
      label = label_arg()
    ),
    annotations = ellmer::tool_annotations(
      title = "Process data",
      read_only_hint = TRUE,
      open_world_hint = FALSE
    )
  )
})
