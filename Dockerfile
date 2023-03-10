# First run an emulated container so that we can
# apt install python for target and use pip to
# install dependencies. This is very slow, even
# for binary distributions, but it allows us to
# install packages with no need to use a cross
# compile toolchain. However, make sure to not
# install packages from sdist since building in
# an emulated gcc is unrealistically slow, in that
# case build it in the second step of the multi
# step build where we use a native cross
# compilation toolchain.
FROM arm32v7/ubuntu:bionic as emulated

# Install python and dependencies
RUN apt update
RUN apt install -y python3-minimal python3-dev python3-pip

# Install numpy using apt since 1) this makes sure we install from
# a binary distribution, 2) this will install the version compiled
# with BLAS accelleration and the dependencies of it.
RUN apt install -y python3-numpy

RUN pip3 install cython

COPY requirements.txt /src/requirements.txt
RUN pip3 install -r /src/requirements.txt

# Extract the python binary and the dependencies to
# its own directory so they are easy to locate
RUN mkdir /generated
RUN cp `readlink -f $(which python3)` /generated/python
RUN for fpath in `python3 -c 'import sys; print(" ".join(sys.path))'`; \
    do mkdir -p /generated/$(dirname $fpath); \
    cp -r $fpath /generated/$fpath; \
    done

COPY copy_lib.sh /copy_lib.sh
RUN mkdir /generated/libs
RUN /copy_lib.sh libblas.so.3 /generated/libs
RUN /copy_lib.sh liblapack.so.3 /generated/libs
RUN /copy_lib.sh libgfortran.so.4 /generated/libs

# Extract the python headers and library headers
# to its own directory so they are easy to locate
COPY copy_headers.py /copy_headers.py
RUN python3 /copy_headers.py  /include

# The second step of the multi step build is performed
# in the official Axis ACAP SDK container. This allows
# us to build from source. We use the container where the
# libraries are built against the ubuntu versions of
# dependencies, this allows us to add a foreign architecture
# and use apt-get to install libraries and headers.
from axisecp/acap-sdk:3.4.2-armv7hf-ubuntu20.04 as builder
COPY --from=emulated /generated /generated
COPY --from=emulated /include /include

# TODO: Make sure we have same version of python on host to build
# external modules as we are running on target.

# Install the cython package since we will use it to cross compile
# the external modules
RUN pip install cython
