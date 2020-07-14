#!/bin/bash
#SBATCH --job-name=ctest
#SBATCH --output=/ru-auth/local/home/agal/ctest1_%a.log
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mail-type=ALL
#SBATCH --mail-user=agal@rockefeller.edu
#SBATCH --array=0-50%100


srun python /ru-auth/local/home/agal/code/anTraX/scripts/classifier_test.py  /ru-auth/local/home/agal/scratch/Classifiers/A36_classifier_analysis -n 2000 --name n2000 --ne 100 --logfile /ru-auth/local/home/agal/classifier_test.log