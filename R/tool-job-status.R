job_status_impl <- function(handle, wait = 0) {
	check_handle(handle)
	if (!job_exists(handle)) {
		stop(
			"No job for '",
			handle,
			"'. Use inspect_object for handles not made by a job."
		)
	}
	wait <- min(max(as.numeric(wait), 0), 60)
	record <- job_info(handle, wait = wait)
	end <- if (is.null(record$finished)) Sys.time() else record$finished
	elapsed <- round(as.numeric(difftime(end, record$started, units = "secs")))

	base <- list(
		handle = handle,
		status = record$status,
		elapsed_s = elapsed
	)
	switch(
		record$status,
		running = base,
		done = c(base, record$result[setdiff(names(record$result), "handle")]),
		failed = c(
			base,
			list(error = record$error, output_tail = output_tail(record$output))
		),
		interrupted = c(
			base,
			list(
				note = "The job's R process ended without a result. Run the tool again.",
				output_tail = output_tail(record$output)
			)
		)
	)
}

add_tool("job_status", function() {
	ellmer::tool(
		job_status_impl,
		name = "job_status",
		description = paste(
			"Check a background job by the handle its tool returned.",
			"Status is running, done (with the tool's result), failed (with the",
			"R error and the last lines of the job's output) or interrupted (the",
			"server restarted or the process crashed)."
		),
		arguments = list(
			handle = ellmer::type_string(
				"Handle returned by the tool that started the job, such as processed_2."
			),
			wait = ellmer::type_number(
				"Seconds to wait for the job to finish before replying, 0 to 60. Default 0.",
				required = FALSE
			)
		),
		annotations = ellmer::tool_annotations(
			title = "Job status",
			read_only_hint = TRUE,
			open_world_hint = FALSE
		)
	)
})
