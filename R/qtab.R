#' Create tabset panels in quarto markdown
#'
#' The function takes in a data frame or a tibble and produces
#' tabset panels for each unique combination of the tabset variables.
#' ***Only works with .qmd files in HTML format.***
#'
#' - Write `#| results: asis` at the beginning of the chunk or
#'   `results='asis'` in the chunk options.
#' - The `data` is sorted internally in the order of `tabset_vars`.
#'   Define the order beforehand, e.g. using factor.
#' - If multiple `tabset_vars` are given, create nested tabsets.
#' - `output_vars` can also be figures or tables if `data` is a tibble.
#' - If factor columns are included in output_vars, they are converted
#'   internally to character.
#' - When outputting tables or figures that use javascript
#'   (such as `{plotly}`, `{leaflet}`, `{DT}`, `{reactable}`, etc.),
#'   it seems javascript dependencies need to be resolved.
#'   A simple solution is to wrap the output in [`htmltools::div()`]
#'   and create a dummy plot in another chunk. See the demo page for details.
#' - The function has an optional argument, `layout`, which allows for
#'   the addition of layout option to the outputs
#'   (see \url{https://quarto.org/docs/authoring/figures.html}).
#'   However, this is intended for simplified use cases and
#'   complex layouts may not work. See Examples for more details.
#'
#' @param data A data frame.
#' @param tabset_vars
#' Variables to use as tabset labels.
#' @param output_vars
#' Variables to display in each tabset panel.
#' @param layout `NULL` or a character vector of length 1 for specifying layout
#' in tabset panel. If not `NULL`, `layout` must begin with at least three
#' or more repetitions of ":" (e.g. ":::").
#' @param heading_levels `NULL` or a positive integer-ish numeric vector of
#' length equal to the number of columns specified in `tabset_vars`.
#' This controls whether it is partially (or entirely) displayed
#' as normal header instead of tabset.
#' * If `NULL`, all output is tabset.
#' * If a positive integer-ish numeric vector, the elements of the vector
#' correspond to the columns specified in `tabset_vars`.
#'    * If the element is integer, the tabset column is displayed as headers
#'    with their level, not tabset. (e.g. 2 means h2 header).
#'    Levels 1 to 6 are recommended. The reason is that quarto supports headers
#'    up to 6. 7 and above will also work, but they are displayed as normal
#'    text. In addition, considering the chapter format,
#'    it is preferable to gradually increase the level, as in 1, 2 and 3.
#'    * If the element is NA, tabset is displayed.
#' @param pills use pills or not
#' @param  tabset_width "default" / "fill" / "justified"
#' @return `NULL` invisibly. This function is called for its side effect.
#' @examples
#' # sample data
#' df <- data.frame(
#'   group1 = c(rep("A", 3), rep("B", 3)),
#'   group2 = rep(c("X", "Y", "Z"), 2),
#'   var1 = rnorm(6),
#'   var2 = rnorm(6),
#'   var3 = rnorm(6)
#' )
#'
#' # Here are examples of the output before it is converted to tabset.
#' # If you want it to actually work, in the .qmd file,
#' # set `results='asis'` in the chunk options or
#' # write `#| results: asis` at the beginning of the chunk.
#'
#' # Basic usage
#' qtab(df, c(group1, group2), c(var1, var2, var3))
#'
#' # Here is an example of the `layout` argument.
#' qtab(
#'   df,
#'   c(group1, group2),
#'   c(var1, var2, var3),
#'   layout = '::: {layout="[2, 3, 5]"}'
#' )
#'
#' # Use heading instead of tabset
#' qtab(
#'   df,
#'   c(group1, group2),
#'   c(var1, var2, var3),
#'   heading_levels = c(2, 3)
#' )
#' @export
qtab <- function(
  data,
  tabset_vars,
  output_vars,
  layout = NULL,
  heading_levels = NULL,
  pills = FALSE,
  tabset_width = "default"
) {
  stopifnot(
    "`pills` must be a `TRUE` or `FALSE`" = isTRUE(pills) || isFALSE(pills)
  )

  tabset_width <- match.arg(tabset_width, c("default", "fill", "justified"))

  tabset_div <- "::: {.panel-tabset}"

  if (pills) {
    tabset_div <- paste(tabset_div, ".nav-pills")
  }

  if (tabset_width %in% c("fill", "justified")) {
    tabset_div <- sprintf("%s .nav-%s", tabset_div, tabset_width)
  }

  tabset_div <- paste(tabset_div, "\n\n")

  l <- do.call(
    validate_data,
    list(
      data = data,
      tabset_vars = substitute(tabset_vars),
      output_vars = substitute(output_vars),
      layout = layout,
      heading_levels = heading_levels
    )
  )

  tabset_names <- l$tabset_names
  output_names <- l$output_names
  heading_levels <- l$heading_levels
  len_tab <- length(tabset_names)

  data <- prep_data(data, tabset_names, output_names)

  tabset_master <- get_tabset_master(
    data,
    tabset_names
  )

  # For each row of the data, print the tabset and output panels ----
  lapply(
    seq_len(nrow(data)),
    function(i) {
      # Check if this row contains a tabset1_start column
      if (is.na(heading_levels[1]) && tabset_master[[i, "tabset1_start"]]) {
        # Add a panel-tabset div
        cat(tabset_div)
      }

      # Loop through each tabset column starting from the second one
      if (len_tab >= 2) {
        lapply(
          2:len_tab,
          function(j) {
            # Check if this row contains a column
            # for the start of the current tabset
            if (tabset_master[[i, paste0("tabset", j, "_start")]]) {

              # Print the heading
              heading_level <- heading_levels[j - 1]

              if (is.na(heading_level)) {
                heading_level <- j - 1
              }

              cat(
                strrep("#", heading_level),
                data[[i, tabset_names[j - 1]]],
                "\n\n"
              )

              # Print a panel-tabset div if the heading_level is NA
              if (is.na(heading_levels[j])) {
                cat(tabset_div)
              }
            }
          }
        )
      }

      heading_level <- heading_levels[len_tab]

      if (is.na(heading_level)) {
        heading_level <- len_tab
      }

      # Print the current tab heading
      # (The output is displayed in this tabset/heading)
      cat(
        strrep("#", heading_level),
        data[[i, tabset_names[len_tab]]],
        "\n\n"
      )

      # Print the layout if it exists
      if (!is.null(layout)) {
        cat(layout, "\n\n")
      }

      # Print the outputs
      lapply(
        seq_along(output_names),
        function(j) {
          out_col <- data[[i, output_names[j]]]

          # add [[1]] at the end because figures and tables
          # are stored as lists in columns
          out <- out_col[[1]]

          # Use `print()` for list-type columns (), otherwise use `cat()`.
          # Using `cat()` avoids unnecessary prefixes
          # such as "[1]" in the output.
          if (is.list(out_col)) {
            print(out)
          } else {
            cat(out)
          }

          cat("\n\n")
        }
      )

      # Close layout-div if layout exists
      if (!is.null(layout)) {
        cat(sub("^(:+).*", "\\1", layout), "\n\n")
      }

      # Loop through each tabset column in reverse order.
      # (To close from the inner tabset.)
      lapply(
        rev(seq_len(len_tab)),
        function(j) {
          # Check if this row contains a column
          # for the end of the current tabset
          if (is.na(heading_levels[j]) &&
                tabset_master[[i, paste0("tabset", j, "_end")]]) {
            # Close the panel-tabset div
            cat("::: \n\n")
          }
        }
      )
    }
  )

  return(invisible())
}

#' @noRd
validate_data <- function(
  data,
  tabset_vars,
  output_vars,
  layout = NULL,
  heading_levels = NULL
) {
  stopifnot(
    "`data` must be a data frame." =
      is.data.frame(data),
    "`data` must have one or more rows." =
      nrow(data) >= 1,
    "`data` must have two or more columns." =
      ncol(data) >= 2
  )

  if (!is.null(layout)) {
    stopifnot(
      "`layout` must be length 1." =
        length(layout) == 1,
      "`layout` must be character." =
        is.character(layout),
      '`layout` must begin with at least three or more repetitions of ":".' =
        grepl("^:{3,}", layout)
    )
  }

  if (!is.null(heading_levels)) {
    stopifnot(
      "`heading_levels` must be numeric." =
        is.numeric(heading_levels),
      "`heading_levels` must be length 1 or greater." =
        length(heading_levels) > 0,
      "`heading_levels` must not include NaN." =
        !is.nan(heading_levels),
      "`heading_levels` must not be infinite." =
        !is.infinite(heading_levels)
    )

    nums <- heading_levels[!is.na(heading_levels)]

    if (length(nums) > 0) {
      stopifnot(
        "`heading_levels` except for NAs must be positive." =
          nums > 0
      )
    }

    heading_levels <- as.integer(heading_levels)
  }

  # Get tabset column names from data based on tabset_vars
  tabset_names <- do.call(
    subset,
    list(x = data, select = substitute(tabset_vars))
  )
  tabset_names <- colnames(tabset_names)

  len_tab <- length(tabset_names)

  stopifnot(
    "`tabset_vars` must be of length 1 or more." =
      len_tab > 0
  )

  tabset_classes <- vapply(
    data[, tabset_names, drop = FALSE],
    typeof,
    character(1)
  )

  tabset_list_cols <- tabset_classes[tabset_classes == "list"]

  if (length(tabset_list_cols) > 0) {
    stop(
      "`tabset_vars` must not contain list columns: ",
      toString(names(tabset_list_cols))
    )
  }

  if (is.null(heading_levels)) {
    heading_levels <- rep(NA_integer_, len_tab)
  }

  stopifnot(
    "The number of columns specified in `tabset_vars`
    and the length of `heading_levels` must be the same." =
      length(heading_levels) == len_tab
  )

  # Get output column names from data based on output_vars
  output_names <- do.call(
    subset,
    list(x = data, select = substitute(output_vars))
  )

  output_names <- colnames(output_names)

  stopifnot(
    "`output_vars` must be of length 1 or more." =
      length(output_names) > 0,

    "There must not be variables that are included in both
    `tabset_vars` and `output_vars`." =
      length(intersect(tabset_names, output_names)) == 0
  )

  list(
    tabset_names = tabset_names,
    output_names = output_names,
    heading_levels = heading_levels
  )
}

#' @noRd
prep_data <- function(data, tabset_names, output_names) {
  data <- data[, c(tabset_names, output_names)]
  data <- data[do.call(order, data[, tabset_names, drop = FALSE]), ]
  data[] <- lapply(
    data,
    function(x) if (is.factor(x)) as.character(x) else x
  )
  data
}

#' @noRd
get_tabset_master <- function(data, tabset_names) {
  len_tab <- length(tabset_names)

  res <- lapply(
    seq_len(len_tab),
    function(idx) {
      gvars <- tabset_names[seq_len(idx) - 1]

      l <- if (length(gvars) > 0) {
        split(data, data[gvars])
      } else {
        list(data)
      }

      a <- lapply(
        l,
        function(df) {
          n <- nrow(df)
          tmp <- data.frame(matrix(ncol = 0, nrow = n))
          tmp[paste0("tabset", idx, "_start")] <- c(TRUE, rep(FALSE, n - 1))
          tmp[paste0("tabset", idx, "_end")] <- c(rep(FALSE, n - 1), TRUE)
          tmp
        }
      )


      do.call(rbind, a)
    }
  )

  res <- do.call(cbind, res)
  rownames(res) <- NULL
  res
}
