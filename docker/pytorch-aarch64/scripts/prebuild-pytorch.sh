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

set -euo pipefail

cd $PACKAGE_DIR
readonly package=pytorch
readonly version=$TORCH_VERSION
readonly src_host=https://github.com/pytorch
readonly src_repo=pytorch
readonly num_cpus=$(grep -c ^processor /proc/cpuinfo)

# clone the pytorch repo if not already present
if [[ ! -d ${src_repo} ]]; then
  # Clone PyTorch
  git clone ${src_host}/${src_repo}.git
  cd ${src_repo}
  git checkout v$version -b v$version
  git submodule sync
  git submodule update --init --recursive
fi

if [[ $ONEDNN_BUILD ]]; then
  # Patch to enable oneDNN (MKL-DNN).
  patch -p1 < $PACKAGE_DIR/pytorch_onednn.patch
  export USE_MKLDNN="ON"

  case $ONEDNN_BUILD in
    reference )
    ;;
    acl )
    export USE_ACL="ON"
    ;;
  esac

  # Update the oneDNN tag in third_party/ideep
  cd third_party/ideep/mkl-dnn
  git checkout $ONEDNN_VERSION
  patch -p1 < $PACKAGE_DIR/onednn_acl_verbose.patch
fi
