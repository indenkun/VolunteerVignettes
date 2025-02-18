#' Convert an existing `README.Rmd` into a vignette
#'
#' While many package lack vignettes, they often contain useful information in
#' the form of a `README.Rmd` file which could in theory form a first draft of a
#' vignette. This function attempts to convert the `README.Rmd` file into a
#' passable vignette, leveraging the same internals as [usethis::use_vignette()]. Once
#' created, an attempt is made to open the file for further editing.
#'
#' This is not guaranteed to create a complete vignette ready to be knit, it
#' just does the easy part. Relative file paths will still need to be updated.
#'
#' In order to perform the conversion from outside of the active project use
#' [usethis::proj_set()] first to set the active project.
#'
#' @param vignette_aut The intended author of the README/vignette. If not
#'   provided, an attempt will be made to extract it from the package's
#'   `DESCRIPTION` file (`Author` or `Authors@R`) as the first person listed
#'   with an `aut` (author) role (if used).
#' @param vignette_title The intended title of the vignette. If not provided,
#'   this will be taken from the Title field of the `DESCRIPTION` file.
#' @param vignette_slug filename to be used as the vignette. By default this
#'   will be README-vignette. This will be converted to a compatible name if
#'   required.
#' @param overwrite (logical) if the vignette already exists, should it be
#'   overwritten?
#'
#' @export
#' @examples
#' \dontrun{
#' ## within an existing package project context
#' README_to_vignette()}
README_to_vignette <- function(vignette_aut = NULL,
                               vignette_title = NULL,
                               vignette_slug = "README-vignette",
                               overwrite = FALSE) {

  check_is_package("README_to_vignette()")

  readme_file <- file.path(usethis::proj_get(), "README.Rmd")
  if (!file.exists(readme_file)) stop("No README.Rmd to convert")
  readme_content <- readLines(readme_file)

  rlang::check_installed("rmarkdown")
  use_dependency("knitr", "Suggests")
  proj_desc_field_update("VignetteBuilder", "knitr", overwrite = TRUE)
  use_dependency("rmarkdown", "Suggests")
  usethis::use_directory("vignettes")
  usethis::use_git_ignore(c("*.html", "*.R"), directory = "vignettes")
  usethis::use_git_ignore("inst/doc")
  path <- file.path("vignettes", fs::path_ext_set(vignette_slug, ".Rmd"))
  if (file.exists(path) && !overwrite) {
    stop(paste(path, "already exists. Use overwrite = TRUE to force rewrite."))
  }
  usethis::ui_done("Creating {usethis::ui_value(path)}")

  ## identify yaml header if present
  readme_yaml_seps <- which(readme_content == "---")
  readme_has_yaml <- length(readme_yaml_seps) > 0

  ## if README yaml is already present, remove it from the README content
  if (readme_has_yaml) {
    readme_yaml_end <- readme_yaml_seps[2] + 1
    readme_content <- readme_content[readme_yaml_end:length(readme_content)]
  }

  ## read plausible author from DESCRIPTION
  desc_file = file.path(usethis::proj_get(), "DESCRIPTION")
  if (is.null(vignette_aut)) {
    descrip_aut <- desc::desc_get_author("aut", file = desc_file)[1]
    if (!is.null(descrip_aut)) {
      ## if pkg uses Authors@R
      vignette_aut <- paste(descrip_aut$given[1], descrip_aut$family[1])
    } else {
      ## if pkg uses Author
      vignette_aut <- sub(" <.*", "", as.character(desc::desc_get("Author", file = desc_file)))
    }
  }

  ## read plausible title from DESCRIPTION
  if (is.null(vignette_title)) {
    vignette_title <- desc::desc_get("Title", file = desc_file)
  }

  vignette_header <- paste0('---
title: "', vignette_title, '"
author: "', vignette_aut, '"
date: "`r Sys.Date()`"
output: rmarkdown::html_vignette
vignette: >
  %\\VignetteIndexEntry{Vignette Title}
  %\\VignetteEngine{knitr::rmarkdown}
  %\\VignetteEncoding{UTF-8}
---
<!-- This vignette was automatically created from README.Rmd -->
')

  vignette_settings <- '
```{r setup, include = FALSE}
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

```'

  ## does the README have knitr config? If not, use the default
  has_config <- length(grep("opts_chunk", readme_content)) > 0
  if (!has_config) vignette_header <- paste0(vignette_header, vignette_settings, collapse = "\n")

  ## write the vignette
  usethis::write_over(
    file.path(usethis::proj_get(), path),
    paste0(vignette_header, paste0(readme_content, collapse = "\n"), collapse = ""),
    quiet = TRUE
  )

  usethis::edit_file(usethis::proj_path(path))

}

#

check_is_package <- utils::getFromNamespace("check_is_package", "usethis")
use_dependency <- utils::getFromNamespace("use_dependency", "usethis")
proj_desc_field_update <- utils::getFromNamespace("proj_desc_field_update", "usethis")
