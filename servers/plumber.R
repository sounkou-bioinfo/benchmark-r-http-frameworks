#!/usr/bin/env Rscript
if (!requireNamespace("plumber", quietly = TRUE)) {
  stop("Missing R package: plumber", call. = FALSE)
}

suppressPackageStartupMessages(library(plumber))

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1L) as.integer(args[[1]]) else 8081L

pr <- plumber::pr() |>
  plumber::pr_get("/ping", function() list(ok = TRUE)) |>
  plumber::pr_get("/ping-text", function() "ok")

plumber::pr_run(pr, host = "127.0.0.1", port = port, docs = FALSE)
