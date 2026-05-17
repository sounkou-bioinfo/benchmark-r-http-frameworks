R HTTP framework benchmarks
================

- [R HTTP framework benchmarks](#r-http-framework-benchmarks)
  - [Machine and benchmark details](#machine-and-benchmark-details)
  - [Workload](#workload)
  - [Results](#results)
  - [Server options](#server-options)
  - [Server code](#server-code)
    - [drogonR native](#drogonr-native)
    - [drogonR plumber-shim](#drogonr-plumber-shim)
    - [plumber](#plumber)
    - [plumber2](#plumber2)
    - [plumber2 mirai async](#plumber2-mirai-async)
    - [RestRserve](#restrserve)

# R HTTP framework benchmarks

This report is generated from machine-readable benchmark output, not by
copying table values by hand.

## Machine and benchmark details

- Results file: `results/latest.csv`
- Run id: `20260517-200327`
- Generated at: 2026-05-17T20:09:32+02:00
- `wrk` args: `-t4 -c50 -d30s`
- Host: Linux 6.8.0-78-generic x86_64 GNU/Linux
- OS: Ubuntu 24.04.3 LTS
- CPU: 13th Gen Intel(R) Core(TM) i5-13500
- Logical CPUs: 20
- Memory: 62.6 GiB
- R: R version 4.6.0 (2026-04-24)
- Package versions: drogonR=0.1.6; plumber=1.3.3; plumber2=0.2.0;
  mirai=2.6.1; RestRserve=1.2.4; Rserve=1.8.19

## Workload

- `GET /ping`: JSON object equivalent to `{"ok": true}` where possible.
- `GET /ping-text`: scalar string `"ok"` through the framework’s default
  response handling.

## Results

| Variant              |          `/ping` JSON | `/ping-text` plain text |
|:---------------------|----------------------:|------------------------:|
| drogonR native       | 180,604 rps, 309.03us |   314,655 rps, 180.47us |
| drogonR plumber-shim | 120,745 rps, 461.09us |   124,543 rps, 449.21us |
| plumber              |    1,124 rps, 42.68ms |      1,127 rps, 42.56ms |
| plumber2             |    1,077 rps, 44.59ms |      1,093 rps, 43.87ms |
| plumber2 mirai async |     268 rps, 178.95ms |       254 rps, 188.36ms |
| RestRserve           |    11,145 rps, 4.80ms |      11,792 rps, 4.55ms |

## Server options

| Variant              | Server options                                                                                                                            |
|:---------------------|:------------------------------------------------------------------------------------------------------------------------------------------|
| drogonR native       | DROGONR_THREADS=4; DROGONR_WORKERS=1                                                                                                      |
| drogonR plumber-shim | DROGONR_THREADS=4; DROGONR_WORKERS=1                                                                                                      |
| plumber              | single R process; no threading option in this benchmark                                                                                   |
| plumber2             | sync handlers; no mirai daemons                                                                                                           |
| plumber2 mirai async | async=TRUE; PLUMBER2_MIRAI_DAEMONS=5                                                                                                      |
| RestRserve           | Rserve HTTP backend on Linux; forked request processing; RESTRSERVE_JIT_LEVEL=0; RESTRSERVE_PRECOMPILE=false; RESTRSERVE_RSERVE_PORT=auto |

Raw `wrk` output and server logs are written under `results/` by
`tools/bench/run.sh`.

## Server code

For transparency, these are the exact server scripts used by the
benchmark.

### drogonR native

Source: `servers/drogonR-native.R`

``` r
#!/usr/bin/env Rscript
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
```

### drogonR plumber-shim

Source: `servers/drogonR-plumber-shim.R`

``` r
#!/usr/bin/env Rscript
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
```

### plumber

Source: `servers/plumber.R`

``` r
#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(plumber))

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1L) as.integer(args[[1]]) else 8081L

pr <- plumber::pr() |>
  plumber::pr_get("/ping", function() list(ok = TRUE)) |>
  plumber::pr_get("/ping-text", function() "ok")

plumber::pr_run(pr, host = "127.0.0.1", port = port, docs = FALSE)
```

### plumber2

Source: `servers/plumber2.R`

``` r
#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(plumber2))

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1L) as.integer(args[[1]]) else 8084L

app <- plumber2::api(host = "127.0.0.1", port = port) |>
  plumber2::api_get("/ping", function() list(ok = TRUE)) |>
  plumber2::api_get("/ping-text", function() "ok")

plumber2::api_run(app, host = "127.0.0.1", port = port,
                  block = TRUE, showcase = FALSE, silent = TRUE)
```

### plumber2 mirai async

Source: `servers/plumber2-mirai.R`

``` r
#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(plumber2)
  library(mirai)
})

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1L) as.integer(args[[1]]) else 8086L
daemons <- as.integer(Sys.getenv("PLUMBER2_MIRAI_DAEMONS", "5"))

mirai::daemons(daemons)
on.exit(mirai::daemons(0), add = TRUE)

app <- plumber2::api(host = "127.0.0.1", port = port, default_async = "mirai") |>
  plumber2::api_get("/ping", function() list(ok = TRUE), async = TRUE) |>
  plumber2::api_get("/ping-text", function() "ok", async = TRUE)

plumber2::api_run(app, host = "127.0.0.1", port = port,
                  block = TRUE, showcase = FALSE, silent = TRUE)
```

### RestRserve

Source: `servers/restrserve.R`

``` r
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
```
