#!/bin/bash
#SBATCH --job-name=ctest
#SBATCH --output=/ru-auth/local/home/agal/logs/class_test_NAME__%a.log
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mail-type=ALL
#SBATCH --mail-user=agal@rockefeller.edu
#SBATCH --array=1-NREP_%100

NAME="NAME_"
N="N_"
LOG="LOG_"
CLASSDIR="CLASSDIR_"
NE="NE_"

srun python /ru-auth/local/home/agal/code/anTraX/scripts/classifier_test.py  $CLASSDIR -n $N --name $NAME --ne $NE --logfile $LOGFILE