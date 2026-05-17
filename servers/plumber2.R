#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(plumber2))

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1L) as.integer(args[[1]]) else 8084L

app <- plumber2::api(host = "127.0.0.1", port = port) |>
  plumber2::api_get("/ping", function() list(ok = TRUE)) |>
  plumber2::api_get("/ping-text", function() "ok")

plumber2::api_run(app, host = "127.0.0.1", port = port,
                  block = TRUE, showcase = FALSE, silent = TRUE)
