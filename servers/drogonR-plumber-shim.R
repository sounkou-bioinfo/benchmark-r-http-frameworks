#!/usr/bin/env Rscript
for (pkg in c("drogonR", "plumber")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Missing R package: ", pkg, call. = FALSE)
  }
}

suppressPackageStartupMessages({
  library(drogonR)
  library(plumber)
})

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1L) as.integer(args[[1]]) else 8083L
threads <- as.integer(Sys.getenv("DROGONR_THREADS", "4"))
workers <- as.integer(Sys.getenv("DROGONR_WORKERS", "1"))

pr <- plumber::pr() |>
  plumber::pr_get("/ping", function() list(ok = TRUE)) |>
  plumber::pr_get("/ping-text", function() "ok")

drogonR::pr_run(pr, host = "127.0.0.1", port = port, docs = FALSE,
                 threads = threads, workers = workers)
