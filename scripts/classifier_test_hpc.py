
from subprocess import Popen, PIPE


#NS = [10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160,170,180,190,200]
#NE = 300
NS = [10,20]
NE = 10

HOME = '/ru-auth/local/home/agal/'
CLASSDIR = HOME + '/scratch/Classifiers/A36_classifier_analysis'
WD = HOME + '/antrax_classifer_test/'
LOGDIR = HOME + 'logs/'
LOGFILE = WD + 'num_examples_test.log'
TEMPLATE = HOME + '/code/anTraX/scripts/classifier_test_jobfile.sh'
JOBFILE = WD + 'jobfile.sh'

#NREP = 50
NREP = 2

if __name__ == '__main__':

    for n in NS:

        # create jobfile
        with open(JOBFILE, 'w') as f:

            name = 'n' + str(n)
            logfile = LOGDIR + 'n' + str(n)
            f.writelines("#!/bin/bash\n")
            f.writelines("#SBATCH --job-name=%s\n" % name)
            f.writelines("#SBATCH --output=%s_%%a.log\n" % logfile)
            f.writelines("#SBATCH --ntasks=1\n")
            f.writelines("#SBATCH --cpus-per-task=%d\n" % int(8))
            f.writelines("#SBATCH --array=%d-%d%%%d\n" % (1, NREP, 10))

            f.writelines("#SBATCH --mail-type=ALL\n")
            f.writelines("#SBATCH --mail-user=agal@rockefeller.edu\n")
            f.writelines("\n")

            cmd = 'python /ru-auth/local/home/agal/code/anTraX/scripts/classifier_test.py ' + \
                CLASSDIR + \
                ' -n ' + str(n) + \
                ' --name ' + name + \
                ' --ne ' + str(NE) + \
                ' --logfile ' + LOGFILE

            f.writelines("srun -N1 %s\n" % cmd)

        p = Popen("sbatch %s" % JOBFILE, stdout=PIPE, shell=True)

        (out, err) = p.communicate()
        print(out)
        out = out.decode("utf-8")
        jid = out.split()[-1]

