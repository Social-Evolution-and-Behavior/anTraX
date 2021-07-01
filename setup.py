from setuptools import setup
from setuptools.command.install import install
import os


def readme():
    with open('README.md') as f:
        return f.read()


setup(name='antrax',
      version='1.0.2',
      description='Python interface to anTraX tracking software',
      long_description=readme(),
      long_description_content_type='text/markdown',
      url='http://github.com/Social-Evolution-and-Behavior/anTraX',
      author='Asaf Gal',
      author_email='agal@rockefeller.edu',
      license='GPL3',
      packages=['antrax'],
      #scripts=['scripts/run_antrax.py'],
      entry_points={'console_scripts': ['antrax=antrax.cli:main', 'antrax-temp=antrax.temp_cli:main']},
      include_package_data=True,
      install_requires=[
            'numpy',
            'imageio',
            'pandas',
            'scipy',
            'clize',
            'tensorflow==1.15',
            'h5py<3.0.0',
            'GitPython',
            'sklearn',
            'ruamel.yaml',
            'pillow',
            'matplotlib',
            'scikit-video',
            'xlrd',
            #'glob3',
            'sigtools',
            'pymatreader @ git+https://github.com/Social-Evolution-and-Behavior/pymatreader.git'
            ],
      zip_safe=False)


class PostInstallCommand(install):
    """Post-installation for installation mode."""
    def run(self):

        # put binaries appropriate for OS in correct location

        # install package
        install.run(self)

        # make app dirs
        home = os.getenv("HOME")
        dirs = [os.path.join(home, '.antrax'),
                os.path.join(home, '.antrax/classifiers'),
                os.path.join(home, '.antrax/parameters')]

        _ = [os.mkdir(d) for d in dirs if not os.path.isdir(d)]

        # download classifiers

        # download parameter files
