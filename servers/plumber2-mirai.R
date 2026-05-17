#!/usr/bin/env Rscript
if (!requireNamespace("plumber2", quietly = TRUE)) {
  stop("Missing R package: plumber2", call. = FALSE)
}
if (!requireNamespace("mirai", quietly = TRUE)) {
  stop("Missing R package: mirai", call. = FALSE)
}

suppressPackageStartupMessages({
  library(plumber2)
  library(mirai)
})

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1L) as.integer(args[[1]]) else 8086L
daemons <- as.integer(Sys.getenv("PLUMBER2_MIRAI_DAEMONS", "5"))
if (is.na(daemons) || daemons < 1L) {
  stop("PLUMBER2_MIRAI_DAEMONS must be a positive integer", call. = FALSE)
}

mirai::daemons(daemons)
on.exit(mirai::daemons(0), add = TRUE)

app <- plumber2::api(host = "127.0.0.1", port = port, default_async = "mirai") |>
  plumber2::api_get("/ping", function() list(ok = TRUE), async = TRUE) |>
  plumber2::api_get("/ping-text", function() "ok", async = TRUE)

plumber2::api_run(app, host = "127.0.0.1", port = port,
                  block = TRUE, showcase = FALSE, silent = TRUE)
