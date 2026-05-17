benchmark-r-http-frameworks
================

A standalone benchmark suite for comparing R HTTP / REST serving
frameworks on the same tiny endpoints.

It is independent of any framework source checkout: it runs installed R
packages and records raw `wrk` output plus machine/package metadata.

## Latest results

Results file: `results/latest.csv`  
Run id: `20260517-202834`  
Generated at: 2026-05-17T20:35:40+02:00  
`wrk` args: `-t4 -c50 -d30s`  
Machine: Ubuntu 24.04.3 LTS; 13th Gen Intel(R) Core(TM) i5-13500; 20
logical CPUs; 62.6 GiB  
R: R version 4.6.0 (2026-04-24)  
Packages: drogonR=0.1.6; plumber=1.3.3; plumber2=0.2.0; mirai=2.6.1;
RestRserve=1.2.4; Rserve=1.8.19; nanonext=1.8.2

| Variant              |          `/ping` JSON | `/ping-text` plain text |
|:---------------------|----------------------:|------------------------:|
| drogonR native       | 180,779 rps, 313.72us |   318,329 rps, 177.84us |
| drogonR plumber-shim | 121,288 rps, 460.90us |   125,360 rps, 460.11us |
| plumber              |    1,123 rps, 42.71ms |      1,124 rps, 42.66ms |
| plumber2             |    1,078 rps, 44.57ms |      1,094 rps, 43.85ms |
| plumber2 mirai async |     270 rps, 177.68ms |       266 rps, 180.17ms |
| RestRserve           |    12,642 rps, 4.22ms |      13,274 rps, 3.97ms |
| nanonext             |    19,546 rps, 2.46ms |      19,960 rps, 2.40ms |

## Frameworks

Current variants:

- `drogonR-native` — `drogonR::dr_app()` + R handler closures
- `drogonR-plumber-shim` — a `plumber` router served by
  `drogonR::pr_run()`
- `plumber` — classic `plumber::pr_run()`
- `plumber2` — `plumber2::api_run()` with synchronous handlers
- `plumber2-mirai` — `plumber2::api_run()` with `async = TRUE` and
  persistent `mirai` daemons
- `RestRserve` — `RestRserve::Application` served by the `Rserve`
  backend
- `nanonext` — direct `nanonext::http_server()` endpoint handlers

## Workload

All variants expose:

- `GET /ping` — JSON object equivalent to `{"ok": true}` where possible
- `GET /ping-text` — scalar string `"ok"` through the framework’s normal
  response path

Default load:

``` bash
wrk -t4 -c50 -d30s http://127.0.0.1:<port>/<route>
```

Override benchmark load and framework concurrency options with
environment variables:

``` bash
WRK_THREADS=8 WRK_CONNECTIONS=100 WRK_DURATION=60s bash tools/bench/run.sh
```

Server options:

``` bash
# drogonR
DROGONR_THREADS=4 DROGONR_WORKERS=1 bash tools/bench/run.sh

# plumber2 async/mirai variant
PLUMBER2_MIRAI_DAEMONS=5 bash tools/bench/run.sh

# RestRserve / Rserve backend on Linux
RESTRSERVE_JIT_LEVEL=0 RESTRSERVE_PRECOMPILE=false bash tools/bench/run.sh
```

RestRserve uses the Rserve HTTP backend. This benchmark targets Linux;
Rserve uses forked request processing for concurrent work.
`RESTRSERVE_RSERVE_PORT` can be set if you need to pin the internal
Rserve/QAP port instead of letting RestRserve choose one.

| Variant              | Server options                                                                                                                            |
|:---------------------|:------------------------------------------------------------------------------------------------------------------------------------------|
| drogonR native       | DROGONR_THREADS=4; DROGONR_WORKERS=1                                                                                                      |
| drogonR plumber-shim | DROGONR_THREADS=4; DROGONR_WORKERS=1                                                                                                      |
| plumber              | single R process; no threading option in this benchmark                                                                                   |
| plumber2             | sync handlers; no mirai daemons                                                                                                           |
| plumber2 mirai async | async=TRUE; PLUMBER2_MIRAI_DAEMONS=5                                                                                                      |
| RestRserve           | Rserve HTTP backend on Linux; forked request processing; RESTRSERVE_JIT_LEVEL=0; RESTRSERVE_PRECOMPILE=false; RESTRSERVE_RSERVE_PORT=auto |
| nanonext             | nanonext http_server; no R-level threading option exposed here                                                                            |

## Requirements

System tools:

``` bash
sudo apt-get install curl wrk
```

R packages:

``` r
install.packages(c("plumber", "plumber2", "mirai", "RestRserve", "nanonext", "rmarkdown", "knitr"))
# plus drogonR from wherever you install it
```

## Run

Run the benchmark:

``` bash
bash tools/bench/run.sh
```

Render the README and full report from latest results:

``` bash
Rscript -e 'rmarkdown::render("README.Rmd")'
Rscript -e 'rmarkdown::render("benchmarks.Rmd")'
```

Run and render the full report in one command:

``` bash
Rscript -e 'rmarkdown::render("benchmarks.Rmd", params = list(run_benchmark = TRUE))'
```

Outputs are written to `results/`:

- raw `wrk` files per framework/route
- server logs
- `comparison-<timestamp>.csv`
- `latest.csv`

`README.md` is generated from `README.Rmd`. `benchmarks.md` is generated
from `benchmarks.Rmd` and includes the server code used for the run.
