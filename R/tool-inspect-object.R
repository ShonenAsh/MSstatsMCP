inspect_object_impl <- function(handle = NULL) {
  if (is.null(handle)) {
    return(list(objects = store_list()))
  }
  store_meta(handle)
}

add_tool("inspect_object", function() {
  ellmer::tool(
    inspect_object_impl,
    name = "inspect_object",
    description = paste(
      "List stored objects, or describe one.",
      "Without a handle: every handle with its type, label, creation time and",
      "source (tool, arguments, input handles).",
      "With a handle: the same fields plus the summary saved when it was made."
    ),
    arguments = list(
      handle = ellmer::type_string(
        "Handle to describe, such as raw_1 or processed_2. Omit to list all.",
        required = FALSE
      )
    ),
    annotations = ellmer::tool_annotations(
      title = "Inspect objects",
      read_only_hint = TRUE,
      open_world_hint = FALSE
    )
  )
})
