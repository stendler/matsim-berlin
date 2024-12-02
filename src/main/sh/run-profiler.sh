#!/usr/bin/env bash
# USAGE:
# ./run-profiler.sh jfr|async-profiler [no]debug [--events <events>|--profile] <java-args>
# EXAMPLE:
# ./run-profiler.sh async-profiler debug --events cache-misses,alloc,lock -classpath matsim-berlin-6.3-v6.0-200-g0dcee95-dirty.jar org.matsim.run.RunQsimComparison
set -e

# Variations:
# - with or without -XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints
# - with additional events: cpu,lock,alloc,cache-misses,L1-dcache-load-misses,LLC-load-misses
# - possibly even only on specified methods: ClassName.methodName
# - mutually exclusive events: wall/cpu/cache-misses/L1-dcache-load-misses/LLC-load-misses
# - requires kernel symbols: cpu/cache-misses/L1-dcache-load-misses/LLC-load-misses

if [ "jfr" = "$1" ]; then
  :
elif [ "async-profiler" = "$1" ]; then
  :
else
    echo >&2 "Missing argument: please specify which profiler to use: $0 <jfr|async-profiler>"
    echo >&2 "USAGE: $0 jfr|async-profiler [no]debug [--events <events>|--profile] <java-args>"
    exit 2
fi

if [ "debug" = "$2" ]; then
  jfr_debug="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints"
elif [ "nodebug" = "$2" ]; then
  jfr_debug=""
else
    echo >&2 "Missing argument: please specify whether to use -XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints: $0 $1 [no]debug"
    exit 3
fi

profiler="$1"
name="$profiler-$2"
shift 2
events="wall,lock,alloc"
if [ "--events" = "$1" ]; then
  events="$2"
  name="$name-$(echo "$events" | tr , _)"
  shift 2
elif [ "--profile" = "$1" ]; then
  # more intrusive profiling
  profile=",settings=profile"
  name="$name-settings-profile"
  shift 1
fi

output_folder="output/${name}/"
profile_output="$output_folder${name}.jfr"
mkdir --parents "$output_folder"


if [ "jfr" = "$profiler" ]; then
  jfr_opts="-XX:StartFlightRecording=name=\"$name\",dumponexit=true,maxsize=0,filename=\"$profile_output\"$profile"
  jfr_opts="$jfr_opts -XX:FlightRecorderOptions=stackdepth=2048"
elif [ "async-profiler" = "$profiler" ]; then
  async_profiler_path="$XDG_DATA_HOME/me.bechberger.ap-loader/3.0/lib/libasyncProfiler.so"
  jfr_opts="-agentpath:$async_profiler_path=start,event=$events,loglevel=INFO,file=$profile_output,alloc=2m,jfrsync,jfr"
fi

printf "Running: '%s'\n" "java $jfr_debug $jfr_opts $*"
printf "***************************************************\n\n"

start=$(date +%s)
java $jfr_debug $jfr_opts "$@"
end=$(date +%s)

printf "\n\n***************************************************"
echo "DONE."

runtime=$((end-start))
echo "$runtime" > "$output_folder/runtime"

# create metadata & summary with jfr cli
jfr metadata "$profile_output" > "$output_folder/metadata.txt"
jfr summary "$profile_output" > "$output_folder/summary.txt"
# todo: explore jfr view outputs - maybe there is something useful to compare here too
