# Expensive tools run in a background R process. The job id is the handle the
# result will be stored under, reserved before the job starts.

.jobs <- new.env()

job_path <- function(handle) {
	file.path(state_dir("jobs"), paste0(handle, ".rds"))
}

# Write then rename, so a reader never sees a half-written record.
job_update <- function(handle, ...) {
	path <- job_path(handle)
	record <- modifyList(readRDS(path), list(...))
	tmp <- paste0(path, ".tmp")
	saveRDS(record, tmp)
	file.rename(tmp, path)
	invisible(record)
}

# `run` names a function defined in R/; the child sources R/ like server.R.
job_start <- function(handle, run, args) {
	output <- file.path(state_dir("logs"), paste0(handle, ".out"))
	saveRDS(
		list(
			handle = handle,
			run = run,
			status = "running",
			started = Sys.time(),
			output = output
		),
		job_path(handle)
	)
	proc <- callr::r_bg(
		job_child,
		args = list(project = getwd(), handle = handle, run = run, args = args),
		stdout = output,
		stderr = "2>&1",
		supervise = TRUE,
		user_profile = FALSE
	)
	assign(handle, proc, envir = .jobs)
	invisible(handle)
}

job_child <- function(project, handle, run, args) {
	setwd(project)
	for (f in c("registry.R", "utils.R", "store.R", "jobs.R")) {
		source(file.path("R", f))
	}
	for (f in list.files("R", pattern = "^tool-.*[.]R$", full.names = TRUE)) {
		source(f)
	}
	tryCatch(
		{
			result <- do.call(run, args)
			job_update(
				handle,
				status = "done",
				finished = Sys.time(),
				result = result
			)
		},
		error = function(e) {
			job_update(
				handle,
				status = "failed",
				finished = Sys.time(),
				error = conditionMessage(e)
			)
		}
	)
	invisible()
}

job_exists <- function(handle) file.exists(job_path(handle))

# A job still marked running with no live process died with the server or
# crashed hard.
job_info <- function(handle, wait = 0) {
	proc <- if (exists(handle, envir = .jobs, inherits = FALSE)) {
		get(handle, envir = .jobs)
	}
	if (!is.null(proc) && wait > 0) {
		proc$wait(timeout = wait * 1000)
	}
	record <- readRDS(job_path(handle))
	if (record$status == "running" && (is.null(proc) || !proc$is_alive())) {
		record <- readRDS(job_path(handle))
		if (record$status == "running") {
			record <- job_update(handle, status = "interrupted")
		}
	}
	record
}

job_list <- function() {
	files <- list.files(state_dir("jobs"), pattern = "[.]rds$")
	handles <- sub("[.]rds$", "", files)
	type <- sub("_[0-9]+$", "", handles)
	id <- as.integer(sub(".*_", "", handles))
	handles <- handles[order(type, id)]
	lapply(handles, function(h) {
		record <- job_info(h)
		list(handle = h, run = record$run, status = record$status)
	})
}

output_tail <- function(path, n = 20) {
	if (!file.exists(path)) {
		return(character(0))
	}
	tail(readLines(path, warn = FALSE), n)
}
