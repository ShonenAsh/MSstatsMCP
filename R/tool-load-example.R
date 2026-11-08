example_datasets <- c("DDARawData", "DIARawData", "SRMRawData")

feature_cols <- c("ProteinName", "PeptideSequence", "PrecursorCharge",
                  "FragmentIon", "ProductCharge", "IsotopeLabelType")

load_example_impl <- function(dataset, label = NULL) {
  dataset <- match.arg(dataset, example_datasets)
  raw <- get(dataset, envir = asNamespace("MSstats"))
  summary <- summarize_input(raw)
  handle <- store_put(
    raw,
    type = "raw",
    source = list(tool = "load_example", args = list(dataset = dataset)),
    summary = summary,
    label = label
  )
  list(handle = handle, label = label, summary = summary)
}

summarize_input <- function(raw) {
  design <- unique(raw[, c("Condition", "BioReplicate", "Run")])
  per_rep <- aggregate(Run ~ Condition + BioReplicate, data = design,
                       FUN = length)
  names(per_rep)[3] <- "runs"
  per_rep <- per_rep[order(per_rep$Condition, per_rep$BioReplicate), ]
  rownames(per_rep) <- NULL

  n_features <- nrow(unique(raw[, feature_cols]))
  n_runs <- length(unique(raw$Run))
  present <- nrow(unique(raw[, c(feature_cols, "Run")]))

  list(
    rows = nrow(raw),
    proteins = length(unique(raw$ProteinName)),
    features = n_features,
    runs = n_runs,
    conditions = length(unique(raw$Condition)),
    missing = list(
      na_intensity = sum(is.na(raw$Intensity)),
      absent_feature_run_rows = n_features * n_runs - present
    ),
    design = per_rep
  )
}

add_tool("load_example", function() {
  ellmer::tool(
    load_example_impl,
    name = "load_example",
    description = paste(
      "Load a bundled MSstats example dataset (already in MSstats input format)",
      "and return a handle of type raw, for use by data_process.",
      "Also returns a summary: rows, proteins, features, runs, conditions,",
      "missing values, and the design (runs per Condition and BioReplicate)."
    ),
    arguments = list(
      dataset = ellmer::type_enum(
        paste(
          "DDARawData: label-free DDA, 6 proteins, 18 runs.",
          "DIARawData: label-free DIA, 2 proteins, 4 runs.",
          "SRMRawData: targeted SRM with labeled reference peptides, 2 proteins, 30 runs."
        ),
        values = example_datasets
      ),
      label = label_arg()
    ),
    annotations = ellmer::tool_annotations(
      title = "Load example data",
      read_only_hint = TRUE,
      open_world_hint = FALSE
    )
  )
})
