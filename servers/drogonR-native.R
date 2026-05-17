#!/usr/bin/env Rscript
if (!requireNamespace("drogonR", quietly = TRUE)) {
  stop("Missing R package: drogonR", call. = FALSE)
}

suppressPackageStartupMessages(library(drogonR))

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1L) as.integer(args[[1]]) else 8080L
threads <- as.integer(Sys.getenv("DROGONR_THREADS", "4"))
workers <- as.integer(Sys.getenv("DROGONR_WORKERS", "1"))

app <- dr_app() |>
  dr_get("/ping", function(req) dr_json(list(ok = TRUE))) |>
  dr_get("/ping-text", function(req) "ok")

dr_serve(app, port = port, threads = threads, workers = workers)
repeat later::run_now(timeoutSecs = 3600)
