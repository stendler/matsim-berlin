#!/bin/bash --login
#SBATCH --time=30:00:00
#SBATCH --partition=smp
#SBATCH --output=/fast/%u/logfile_%x-%j.log
#SBATCH --nodes=1                       # How many computing nodes do you need (for MATSim usually 1)
#SBATCH --ntasks=1                      # How many tasks should be run (For MATSim usually 1)
#SBATCH --cpus-per-task=10              # Number of CPUs per task (For MATSim usually 8 - 12)
#SBATCH --mem=48G                       # RAM for the job
#SBATCH --job-name=matsim-berlin-profiling  # name of your run, will be displayed in the joblist
#SBATCH --mail-type=BEGIN,END,FAIL			# When to notify via mail
#SBATCH --mail-user=stendler@campus.tu-berlin.de  # Your email address

date
hostname
lscpu

# ensure SLURM_JOB_NAME is set
if [ -z "$SLURM_JOB_NAME" ]; then
  echo >&2 "SLURM_JOB_NAME not set!"
  exit 2
fi

printf "TMPDIR set to %s" "$TMPDIR\n"
# jfr went out of disk to write - check potential directories, where it will write to
df -h /tmp /fast /scratch

echo "Running $SLURM_JOB_NAME for $USER"
# use output dirs on fast storage
output_dir="/fast/$USER/$SLURM_JOB_NAME/"
mkdir --parents "$output_dir/matsim-berlin"

module add java/21
java -version
printf "jfr version: "
jfr version

# last line for the exit code
./run-profiler.sh --output "$output_dir" "$@" --output "$output_dir/matsim-berlin" run
