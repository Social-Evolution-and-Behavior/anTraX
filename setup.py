from setuptools import setup
from setuptools.command.install import install

def readme():
    with open('README.md') as f:
        return f.read()


setup(name='antrax',
      version='0.2-alpha',
      description='Python interface to anTraX tracking software',
      long_description=readme(),
      long_description_content_type='text/markdown',
      url='http://github.com/Social-Evolution-and-Behavior/anTraX',
      author='Asaf Gal',
      author_email='agal@rockefeller.edu',
      license='GPL3',
      packages=['antrax'],
      scripts=['scripts/run_antrax.py'],
      include_package_data=True,
      install_requires=[
            'numpy',
            'pandas',
            'scipy',
            'clize',
            'tensorflow==1.15',
            'h5py',
            'keras',
            'sklearn',
            'ruamel-yaml',
            'pillow',
            'matplotlib',
            'scikit-video',
            'xlrd',
            'glob3',
            'sigtools',
            'pymatreader @ git+https://github.com/Social-Evolution-and-Behavior/pymatreader.git'
            ],
      zip_safe=False)


class PostInstallCommand(install):
    """Post-installation for installation mode."""
    def run(self):

        # install package
        install.run(self)

        # make app dir

        # download pre trained classifiers
