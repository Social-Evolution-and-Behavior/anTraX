import os
from os.path import join
from glob import glob
from clize import run
from shutil import copyfile, copy


def rename(expdir, new_expname):
    
    expname = expdir.split('/')[-1]
    new_expdir = expdir.replace(expname, new_expname)
    os.rename(expdir, new_expdir)

    files = glob(new_expdir+'/*/*.*') + glob(new_expdir+'/*/*/*.*')
    new_files = [x.replace(expname, new_expname) for x in files]

    for f, new_f in zip(files, new_files):
        os.rename(f, new_f)

    
if __name__ == '__main__':

    run(rename)
