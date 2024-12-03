#!/usr/bin/env sh

# register all profiler job runs
memory="${RUN_MEMORY:-46G}"
jvm_opts="-Xmx$memory -Xms$memory -XX:+AlwaysPreTouch -XX:+UseParallelGC"
jvm_command="-classpath ${1:-"matsim-berlin-6.3.jar"} org.matsim.run.RunQsimComparison --iterations=500 --1pct"

sbatch_command() (
  run="$1"
  shift 1

  sbatch --job-name="matsim-berlin-profiling-$run-$i" --profile=TASK --constraint="cputype:xeon2630v2" ./run-profiler-job.sh "$@" --runId="matsim-berlin-6.3-$run"
  sleep 1 # https://slurm.schedmd.com/sbatch.html#SECTION_PERFORMANCE
)

for i in 1 2 3; do
    sbatch_command baseline baseline nodebug $jvm_opts $jvm_command
    sbatch_command jfr jfr debug $jvm_opts $jvm_command
    sbatch_command jfr-profile jfr debug --profile $jvm_opts $jvm_command
done
