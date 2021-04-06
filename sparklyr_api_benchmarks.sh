# === PREPARE SCRIPTS ===============================================
set -e

## Benchmarking script ----------------------------------------------
echo "
# options(sparklyr.dbplyr.edition = 1L)
# options(sparklyr.log.invoke = 'cat')
options(width = 150)
library(dplyr, warn.conflicts = FALSE, quietly = TRUE)
library(dbplyr, warn.conflicts = FALSE, quietly = TRUE)
library(sparklyr, warn.conflicts = FALSE, quietly = TRUE)
config <- spark_config()
# config[['sparklyr.dbplyr.edition']] = 1L
sc <- spark_connect('local', config = config)
cars <- copy_to(sc, df = datasets::mtcars, name = 'cars')
versions <- toString(invisible(lapply(
  sessionInfo()[['otherPkgs']],
  function(x) paste(x[['Package']], x[['Version']])
)))

message(paste('Microbenchmark for:', versions))

mb <- microbenchmark::microbenchmark(
  unit = 'ms',
  times = 20,
  sdf_register = {
    res <- cars %>%
      mutate(z = 26) %>%
      sdf_register()
  },
  spark_dataframe = {
    res <- cars %>%
      mutate(y = 25) %>%
      spark_dataframe()
  },
  mutate_one = {
    res <- cars %>%
      mutate(a = 1)
  },
  mutate_three = {
    res <- cars %>%
      mutate(a = 1) %>%
      mutate(b = 2) %>%
      mutate(c = 3)
  },
  mutate_seven = {
    res <- cars %>%
      mutate(a = 1) %>%
      mutate(b = 2) %>%
      mutate(c = 3) %>%
      mutate(d = 4) %>%
      mutate(e = 5) %>%
      mutate(f = 6) %>%
      mutate(g = 7)
  },
  filter = {
    res <- cars %>%
      dplyr::filter(cyl == 1) %>%
      dplyr::filter(gear == 4)
  },
  join = {
    res <- cars %>%
      select(-gear) %>%
      left_join(cars, by = 'cyl') %>%
      left_join(cars, by = 'gear')
  },
  select = {
   res <- cars %>%
     select(mpg, cyl, disp, hp) %>%
     select(mpg, cyl, disp) %>%
     select(mpg)
 }
)
print(mb, signif = 3)
" > ./bench.R


## Install Latest package versions ----------------------------------
echo "
rp <- 'https://packagemanager.rstudio.com/all/__linux__/focal/latest'
options(repos = rp, Ncpus = parallel::detectCores())
pkgs <- c(
  'remotes',
  'dplyr',
  'dbplyr',
  'tidyr',
  'sparklyr',
  'DBI'
)
message('Installing packages: ', toString(pkgs))
install.packages(pkgs, quiet = TRUE)
" > ./upgrade.R


## Install Current DEV version of sparklyr from GitHub --------------
echo "
options(download.file.method = 'libcurl')
message('Installing sparklyr from GitHub')
remotes::install_github('sparklyr/sparklyr', quiet = TRUE)
" > ./devsparklyr.R


# === BENCHMARKS RUN ================================================

## Old versions -----------------------------------------------------
echo "\n\n===== Legacy package versions ====="
docker run --rm \
  -v $(pwd)/bench.R:/bench.R \
  jozefhajnala/jozefio \
  /bin/bash -c "set -e; Rscript /bench.R"

## Current CRAN -----------------------------------------------------
echo "\n\n===== Current CRAN package versions ====="
docker run --rm \
  -v $(pwd)/bench.R:/bench.R \
  -v $(pwd)/upgrade.R:/upgrade.R \
  jozefhajnala/jozefio \
  /bin/bash -c "set -e; Rscript /upgrade.R; Rscript /bench.R"

## Current CRAN + DEV sparklyr --------------------------------------
echo "\n\n===== Current CRAN package versions + DEV sparklyr ====="
docker run --rm \
  -v $(pwd)/bench.R:/bench.R \
  -v $(pwd)/upgrade.R:/upgrade.R \
  -v $(pwd)/devsparklyr.R:/devsparklyr.R \
  jozefhajnala/jozefio \
  /bin/bash -c "set -e; Rscript /upgrade.R; Rscript /devsparklyr.R; Rscript /bench.R"


# === CLEANUP =======================================================
rm ./bench.R
rm ./upgrade.R
rm ./devsparklyr.R
