# Install miniconda
if [[ "$TRAVIS_PYTHON_VERSION" == "2.7" ]]; then
	wget https://repo.continuum.io/miniconda/Miniconda2-latest-Linux-ppc64le.sh -O miniconda.sh;
else
    wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-ppc64le.sh -O miniconda.shfi

bash miniconda.sh -b -p $HOME/miniconda
export PATH="$HOME/miniconda/bin:$PATH"
echo 'PATH =' $PATH
conda config --set always_yes yes
conda info -a


# Install conda build
conda install conda-build

# Install lftp
sudo apt-get install lftp