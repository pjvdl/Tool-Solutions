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

cd $PACKAGE_DIR/$src_repo

MAX_JOBS=${NP_MAKE:-$((num_cpus / 2))} OpenBLAS_HOME=$OPENBLAS_DIR/lib CXX_FLAGS="$BASE_CFLAGS -O3" LDFLAGS=$BASE_LDFLAGS USE_OPENMP=1 USE_LAPACK=1 USE_CUDA=1 USE_FBGEMM=0 USE_DISTRIBUTED=0 python setup.py bdist_wheel
