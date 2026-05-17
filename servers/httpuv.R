#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(httpuv))

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1L) as.integer(args[[1]]) else 8088L

app <- list(
  call = function(request) {
    path <- request$PATH_INFO
    if (identical(path, "/ping")) {
      list(
        status = 200L,
        headers = list("Content-Type" = "application/json"),
        body = '{"ok":true}'
      )
    } else if (identical(path, "/ping-text")) {
      list(
        status = 200L,
        headers = list("Content-Type" = "application/json"),
        body = '"ok"'
      )
    } else {
      list(
        status = 404L,
        headers = list("Content-Type" = "text/plain"),
        body = "not found"
      )
    }
  }
)

server <- httpuv::startServer("127.0.0.1", port, app, quiet = TRUE)
on.exit(httpuv::stopServer(server), add = TRUE)
repeat httpuv::service(timeout = 1000)
