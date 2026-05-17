#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(nanonext))

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1L) as.integer(args[[1]]) else 8087L

server <- nanonext::http_server(
  url = sprintf("http://127.0.0.1:%d", port),
  handlers = list(
    nanonext::handler(
      "/ping",
      \(request) list(
        status = 200L,
        headers = c("Content-Type" = "application/json"),
        body = '{"ok":true}'
      )
    ),
    nanonext::handler(
      "/ping-text",
      \(request) list(
        status = 200L,
        headers = c("Content-Type" = "application/json"),
        body = '"ok"'
      )
    )
  )
)

server$start()
repeat later::run_now(timeoutSecs = 3600)
