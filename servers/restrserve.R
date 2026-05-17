#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(RestRserve))

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1L) as.integer(args[[1]]) else 8085L
jit_level <- as.integer(Sys.getenv("RESTRSERVE_JIT_LEVEL", "0"))
precompile <- tolower(Sys.getenv("RESTRSERVE_PRECOMPILE", "false")) %in%
  c("true", "1", "yes", "y")
rserve_port <- Sys.getenv("RESTRSERVE_RSERVE_PORT", "")

app <- RestRserve::Application$new(content_type = "application/json")
app$add_get("/ping", function(request, response) {
  response$set_body(list(ok = TRUE))
})
app$add_get("/ping-text", function(request, response) {
  response$set_body("ok")
})

backend <- RestRserve::BackendRserve$new(
  jit_level = jit_level,
  precompile = precompile
)
start_args <- list(app = app, http_port = port)
if (nzchar(rserve_port)) {
  start_args$port <- as.integer(rserve_port)
}
do.call(backend$start, start_args)
