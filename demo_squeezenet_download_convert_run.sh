#!/bin/bash

# Copyright (c) 2018 Intel Corporation
# 
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#       http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

error() {
	local code="${3:-1}"
	if [[ -n "$2" ]];then
		echo "Error on or near line $1: $2; exiting with status ${code}"
	else
		echo "Error on or near line $1; exiting with status ${code}"
	fi
	exit "${code}" 
}
trap 'error ${LINENO}' ERR

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR=$ROOT_DIR/..

if [[ $EUID -ne 0 ]]; then
	echo "ERROR: to install CV SDK dependencies, you must run this script as root." >&2
    echo "Please try again with "sudo -E $0", or as root." >&2
    exit 1
fi

model_name="squeezenet1.1"
target_device="CPU"
target_precision="FP32"
target_image_path="$ROOT_DIR/demo/car.png"

run_again="Then run the script again\n\n"
dashes="\n\n###################################################\n\n"

# Step 1. Download the Caffe model and the prototxt of the model
printf "${dashes}"
printf "\n\nDownloading the Caffe model and the prototxt"

model_dir="${model_name}"
ir_dir="ir/${model_name}"
dest_model_proto="${model_name}.prototxt"
dest_model_weights="${model_name}.caffemodel"
cur_path=$PWD

printf "\nInstalling dependencies\n"

if [[ -f /etc/centos-release ]]; then
    DISTRO="centos"
elif [[ -f /etc/lsb-release ]]; then
    DISTRO="ubuntu"
fi

if [[ $DISTRO == "centos" ]]; then
	sudo -E rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-1.el7.nux.noarch.rpm || true
	sudo -E yum install -y epel-release
	sudo -E yum install -y ffmpeg gstreamer-plugins-base
    
	# check installed Python version
    if command -v python3.5 >/dev/null 2>&1; then
        python_binary=python3.5
        pip_binary=pip3.5
    fi
    if command -v python3.6 >/dev/null 2>&1; then
        python_binary=python3.6
        pip_binary=pip3.6
    fi
    if [ -z "$python_binary" ]; then
        sudo -E yum install -y https://centos7.iuscommunity.org/ius-release.rpm
        #sudo -E yum install -y python36u easy_install python36u-pip
        sudo -E yum install -y python36u python36u-pip
        sudo -E pip3.6 install virtualenv
        python_binary=python3.6
        pip_binary=pip3.6
    fi
elif [[ $DISTRO == "ubuntu" ]]; then
    printf "Run sudo -E apt -y install python3-pip virtualenv cmake libpng-dev libcairo2-dev libpango1.0-dev libglib2.0-dev libgtk2.0-dev libgstreamer1.0-dev libswscale-dev libavcodec-dev libavformat-dev\n\n"
    sudo -E apt update
    sudo -E apt -y install python3-pip virtualenv cmake libpng-dev libcairo2-dev libpango1.0-dev libglib2.0-dev libgtk2.0-dev libgstreamer1.0-dev libswscale-dev libavcodec-dev libavformat-dev
    python_binary=python3
    pip_binary=pip3
fi

if ! command -v $python_binary &>/dev/null; then
    printf "\n\nPython 3.5 (x64) or higher is not installed. It is required to run Model Optimizer, please install it. ${run_again}"
    exit 1
fi

sudo -E $pip_binary install pyyaml requests

printf "Run $ROOT_DIR/model_downloader/downloader.py --name \"${model_name}\"\n\n"
$python_binary "$ROOT_DIR/model_downloader/downloader.py" --name "${model_name}"

# Step 2. Configure Model Optimizer
printf "${dashes}"
printf "Configure Model Optimizer\n\n"

if [[ -z "${INTEL_CVSDK_DIR}" ]]; then
  	printf "\n\nINTEL_CVSDK_DIR environment variable is not set. Trying to run ./setvars.sh to set it. \n"
  	
    if [ -e "$ROOT_DIR/inference_engine/bin/setvars.sh" ]; then # for Intel Deep Learning Deployment Toolkit package
        setvars_path="$ROOT_DIR/inference_engine/bin/setvars.sh"
    elif [ -e "$ROOT_DIR/../bin/setupvars.sh" ]; then # for Intel CV SDK package
        setvars_path="$ROOT_DIR/../bin/setupvars.sh"
    elif [ -e "$ROOT_DIR/../setupvars.sh" ]; then # for Intel GO SDK package
        setvars_path="$ROOT_DIR/../setupvars.sh"
    else
        printf "Error: setvars.sh is not found\n"
    fi 
    if ! source $setvars_path ; then
        printf "Unable to run ./setvars.sh. Please check its presence. ${run_again}"
        exit 1
    fi
fi

cvsdk_install_dir="${INTEL_CVSDK_DIR}"

prereqs_mo_path="${cvsdk_install_dir}/deployment_tools/model_optimizer/install_prerequisites"
prereqs_script="install_prerequisites.sh"

if [ ! -e "${prereqs_mo_path}/../venv" ]; then
	cd $prereqs_mo_path
	mkdir "../venv"
	if ! source $prereqs_script ; then
		printf "\n\nUnable to create virtual environment. Do you want to install dependencies globally?\n"
		printf "\nWARNING: this can overwrite your globally installed Python packages.\n"

		read -p "Type 'y' to install dependencies globally or 'n' to exit: " -n 1 -r
		echo    # (optional) move to a new line
		if [[ ! $REPLY =~ ^[Yy]$ ]]
		then
		    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
		else 
			rm -rf ../venv
			sudo -E $pip_binary install -r ../requirements.txt
		fi
	fi
	cd $cur_path
else
	printf "Found existing environment. Skipping installing dependencies for Model Optimizer.\n"
	printf "If you want to install again, remove venv directory. ${run_again}"
fi
source $prereqs_mo_path/../venv/bin/activate

# Step 3. Convert a model with Model Optimizer
printf "${dashes}"
printf "Convert a model with Model Optimizer\n\n"

mo_path="${cvsdk_install_dir}/deployment_tools/model_optimizer/mo.py"

if [ ! -e $ir_dir ]; then
	export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=cpp
	printf "Run $python_binary $mo_path --input_model $ROOT_DIR/demo/classification/squeezenet/1.1/caffe/squeezenet1.1.caffemodel --output_dir $ir_dir --data_type $target_precision\n\n"
	$python_binary $mo_path --input_model "$ROOT_DIR/demo/classification/squeezenet/1.1/caffe/squeezenet1.1.caffemodel" --output_dir $ir_dir --data_type $target_precision
else
    printf "\n\nTarget folder ${ir_dir} already exists. Skipping IR generation."
    printf "If you want to convert a model again, remove the entire ${$ir_dir} folder. ${run_again}"
    return
fi

# Step 4. Build samples
printf "${dashes}"
printf "Build Inference Engine samples\n\n"

samples_path="${cvsdk_install_dir}/deployment_tools/inference_engine/samples"
cd $samples_path

if ! command -v cmake &>/dev/null; then
    printf "\n\nCMAKE is not installed. It is required to build Inference Engine samples. Please install it. ${run_again}"
    exit 1
fi

build_dir="${ROOT_DIR}/inference_engine/samples/build"
if [ ! -e "$build_dir/intel64/Release/classification_sample" ]; then
	mkdir -p $build_dir
	cd $build_dir
	cmake -DCMAKE_BUILD_TYPE=Release ..
	make -j8 classification_sample
else
    printf "\n\nTarget folder ${build_dir} already exists. Skipping samples building."
    printf "If you want to rebuild samples, remove the entire ${build_dir} folder. ${run_again}"
fi

# Step 5. Run samples
printf "${dashes}"
printf "Run Inference Engine classification sample\n\n"

binaries_dir="${cvsdk_install_dir}/deployment_tools/inference_engine/samples/build/intel64/Release"
cd $binaries_dir

printf "Run ./classification_sample -d $target_device -i $target_image_path -m $ROOT_DIR/demo/${ir_dir}/squeezenet1.1.xml\n\n"
cp -f $ROOT_DIR/demo/squeezenet1.1.labels $ROOT_DIR/demo/${ir_dir}/

./classification_sample -d $target_device -i $target_image_path -m "$ROOT_DIR/demo/${ir_dir}/squeezenet1.1.xml"
