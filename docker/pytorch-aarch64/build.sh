#!/usr/bin/env bash

# *******************************************************************************
# Copyright 2020 Arm Limited and affiliates.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *******************************************************************************

# Inputs:
#   docker_target - the docker build target
#   docker_name   - docker tags
#   buildx_target - (optional) if cross-building, specify the buildx target
function build_docker {
  if [[ $buildx_target == "" ]]; then
    # standard docker build
    docker build $extra_args --target pytorch-base -t pytorch-base-v$tf_version:latest .
  else
    # buildx cross build
    EXISTING=`docker buildx ls | sed -rn 's/^.*(jetsonubuntu).*$/\1/p'`
    if [[ EXISTING == "" ]]; then
      docker buildx create --name jetsonubuntu
    fi
    docker buildx use jetsonubuntu
    docker buildx build --platform linux/arm64 $extra_args --target $docker_target -t $docker_name:latest --load .
  fi
}

# Staged docker build for PyTorch
# ==================================

################################################################################
function print_usage_and_exit {
  echo "Usage: build.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -h, --help                   Display this message"
  echo "      --jobs                   Specify number of jobs to run in parallel during the build"
  echo "      --onednn/--dnnl          Build and link to oneDNN / DNNL:"
  echo "                                 * reference    - use the C++ reference kernels throughout."
  echo "                                 * acl          - use Arm Compute Library primitives where available (default)."
  echo "      --build-type             Type of build to perform:"
  echo "                                 * base       - build the basic portion of the image, OS and essential packages"
  echo "                                 * libs       - build image including maths libraries and Python3."
  echo "                                 * tools      - build image including Python3 venv, with numpy."
  echo "                                 * dev        - build image including Bazel and PyTorch, with sources."
  echo "                                 * pytorch    - build image including PyTorch build and benchmarks installed"
  echo "                                 * full       - build all images."
  echo "      --clean                  Pull a new base image and build without using any cached images."
  echo ""
  echo "Example:"
  echo "  build.sh --build-type full"
  exit $1
}

################################################################################

# Enable Buildkit
# Required for advanced multi-stage builds
# Requires Docker v 18.09.1
export DOCKER_BUILDKIT=1

# Default build flags
build_base_image=
build_libs_image=
build_tools_image=
build_dev_image=
build_pytorch_image=1

readonly target_arch="aarch64"
readonly host_arch=$(arch)

if ! [ "$host_arch" == "$target_arch" ]; then
  echo "Host is $(arch). Using buildx to build a multi-architecture image for architecture $target_arch"
fi


# Default args
extra_args=""
nproc_build=
clean_build=
onednn=

while [ $# -gt 0 ]
do
  case $1 in
    --build-type )
      case $2 in
        base )
          build_base_image=1
          build_libs_image=
          build_tools_image=
          build_dev_image=
          build_pytorch_image=
          ;;
        libs )
          build_base_image=
          build_libs_image=1
          build_tools_image=
          build_dev_image=
          build_pytorch_image=
          ;;
         tools )
          build_base_image=
          build_libs_image=
          build_tools_image=1
          build_dev_image=
          build_pytorch_image=
          ;;
        dev )
          build_base_image=
          build_libs_image=
          build_tools_image=
          build_dev_image=1
          build_pytorch_image=
          ;;
        full )
          build_base_image=1
          build_libs_image=1
          build_tools_image=1
          build_dev_image=1
          build_pytorch_image=1
          ;;
        pytorch )
          build_base_image=
          build_libs_image=
          build_tools_image=
          build_dev_image=
          build_pytorch_image=1
          ;;
        * )
          echo "Error: $2 is an invalid build type!"
          print_usage_and_exit 1
          ;;
      esac
      shift
      ;;

    --jobs )
      nproc_build=$2
      shift
      ;;

    --clean )
      clean_build=1
      ;;

    --onednn | --dnnl )
      case $2 in
        reference )
          onednn="reference"
          shift
        ;;
        acl )
          onednn="acl"
          shift
        ;;
        * )
          onednn="acl"
          ;;
      esac
      ;;


    -h | --help )
      print_usage_and_exit 0
      ;;

  esac
  shift
done

exec > >(tee -i build.log)
exec 2>&1

if [[ $nproc_build ]]; then
  # Set -j to use for builds, if specified
  extra_args="$extra_args --build-arg njobs=$nproc_build"
fi

if [[ $clean_build ]]; then
  # Pull a new base image, and don't use any caches
  extra_args="--pull --no-cache $extra_args"
fi

if [[ $onednn ]]; then
  # Use oneDNN backend
  extra_args="--build-arg onednn_opt=$onednn $extra_args"
fi

echo $extra_args

if [[ $build_base_image ]]; then
  # Stage 1: Base image, Ubuntu with core packages and GCC9
  docker_target="pytorch-base"
  docker_name="pytorch-base"
  build_docker
fi

if [[ $build_libs_image ]]; then
  # Stage 2: Libs image, essential maths libs and Python built and installed
  docker_target="pytorch-libs"
  docker_name="pytorch-libs"
  build_docker
fi

if [[ $build_tools_image ]]; then
  # Stage 3: Tools image, Python3 venv added with additional Python essentials
  docker_target="pytorch-tools"
  docker_name="pytorch-tools"
  build_docker
fi

if [[ $build_dev_image ]]; then
  # Stage 4: Adds PyTorch build with sources
  docker_target="pytorch-dev"
  docker_name="pytorch-dev"
  build_docker
fi

if [[ $build_pytorch_image ]]; then
  # Stage 5: Adds PyTorch examples
  docker_target="pytorch"
  docker_name="pytorch"
  build_docker
fi

