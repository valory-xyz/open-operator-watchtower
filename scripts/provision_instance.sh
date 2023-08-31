#!/bin/bash

# ------------------------------------------------------------------------------
#
#   Copyright 2023 Valory AG
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# ------------------------------------------------------------------------------


### usage
# mac/linux: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/valory-xyz/open-aea/main/scripts/install.sh)"
OPEN_AUTONOMY_VERSION=0.11.1
USER=ubuntu
PORT="26656"
TENDERMINT_P2P_URL=$(curl icanhazip.com):$PORT


bad_os_type() {
	echo "OS $OSTYPE is not supported!"
	exit 1
}

check_linux() {
	# check any deb distribution!
	is_ubuntu=`cat /etc/issue|grep -i Ubuntu`
	if  [[ -z $is_ubuntu ]];
	then
		echo "Only Ubuntu, MacOS are supported at the moment with this script. please use install.ps1 for Windows 10."
		exit 1
	fi
	install_on_ubuntu
}


is_python3(){
	return `which python3`
}

is_python_version_ok() {
	if which python3 2>&1 >/dev/null;
	then
		version=`python3 -V 2>/dev/null`
		if [[ -z `echo $version|grep -E 'Python 3\.(7|8|9|10)\.[0-9]+'` ]];
		then
			echo "Python3 version: ${version} is not supported. Supported versions are 3.7, 3.8, 3.9, 3.10."
			return 1
		fi
		return 0
	else
		echo "Python is not installed"
		return 1
	fi
}


install_autonomy (){
	touch ~/.profile
	py_user_base=$(sudo -u $USER python3 -m site --user-base)
	echo  >>~/.bashrc
	echo 'export PATH=$PATH'":${py_user_base}/bin" >>/home/$USER/.bashrc 
    echo "Installed autonomy for $USER"
	source /home/$USER/.bashrc  # sometimes ~/.local/bin is not in PATH
    export PATH=$PATH":${py_user_base}/bin"

	echo "Installing Open Autonomy $OPEN_AUTONOMY_VERSION for user $USER"
	output=$(sudo -u $USER pip3 install --user open-autonomy[all]==$OPEN_AUTONOMY_VERSION --force --no-cache-dir)
	if [[  $? -ne 0 ]];
	then
		echo "$output"
		echo 'Failed to install Open Autonomy'
		exit 1
	fi

    # Patch for issue https://github.com/docker/docker-py/issues/3113
	echo "Installing Python requests @2.28.1 for user $USER"
	output=$(sudo -u $USER pip3 install --user pip install requests==2.28.1 --force --no-cache-dir)
	if [[  $? -ne 0 ]];
	then
		echo "$output"
		echo '\n\nFailed to install requests'
		exit 1
	fi	

	output=$(su - $USER -c "aea --help" 2>&1)
	if [[  $? -ne 0 ]];
	then
		echo "$output"
		echo 'Test run of Open AEA failed!'
		exit 1
	fi

	output=$(su - $USER -c "autonomy --help" 2>&1)
	if [[  $? -ne 0 ]];
	then
		echo "$output"
		echo 'Test run of Open Autonomy failed!'
		exit 1
	fi

	echo "Open Autonomy successfully installed!"
	echo "It's recommended to open a new shell to work with Autonomy."
}

install_ubuntu_deps(){
	# always install it cause python3-dev can be missing! also it's not consuming much time.
	echo "Installing python3 and dependencies"
	output=$(sudo bash -c "apt update &&  apt install python3 python3-pip python3-dev -y" 2>&1)
	if [[  $? -ne 0 ]];
	then
		echo "$output"
		echo -n '\n\nFailed to install required packages!'
		exit 1
	fi

}

install_docker(){
	echo "Installing Docker"
	output=$(curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh && sudo gpasswd -a $USER docker && newgrp docker 2>&1)
	if [[  $? -ne 0 ]];
	then
		echo "$output"
		echo -n '\n\nFailed to install Docker'
		exit 1
	fi
}


install_tendermint(){
	echo "Installing Tendermint"
	output=$(curl -fsSL https://github.com/tendermint/tendermint/releases/download/v0.34.19/tendermint_0.34.19_linux_amd64.tar.gz | tar -xz -C /tmp && sudo mv /tmp/tendermint /usr/local/bin/)

	if [[  $? -ne 0 ]];
	then
		echo "$output"
		echo -n '\n\nFailed to install Tendermint'
		exit 1
	fi	
}

check_python_version(){
	output=$(is_python_version_ok)
	if [[ $? -eq 1 ]];
	then
		echo "$output"
		echo "Can not install supported Python version. Probably distribution is too old."
		exit 1
	fi
}


setup_host(){
	echo export TENDERMINT_P2P_URL=$TENDERMINT_P2P_URL >>/home/$USER/.bashrc
	echo "Setup host vars."
}


install_on_ubuntu(){
	setup_host
	install_ubuntu_deps
	check_python_version
	install_docker
	install_tendermint
	install_autonomy
}

ensure_brew(){
	output=`which brew`
	if [[ $? -ne 0 ]];
	then
		echo "Installing homebrew. Please pay attention, it can ask for the password and aggree to install xcode tools."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
		if [[ $? -eq 0 ]];
		then
			echo "Homebrew was installed!"
		else
			echo "Homebrew failed to install!"
		fi
	fi
}

mac_install_python(){
	output=`is_python_version_ok`
	if [[ $? -eq 0 ]];
	then
		echo "Python supported version already installed!"
		return 0
	fi

	ensure_brew
	echo "Install python3.8. It takes long time."
	output=$(brew install python@3.8 2>&1)
	if [[ $? -eq 0 ]];
	then
		echo "Python was successfully installed!"
		return 0
	else
		echo "$output"
		echo "Python failed to install!"
		exit 1
	fi
}

install_on_mac(){
	mac_install_python
	check_python_version
	install_autonomy
}

main(){
	echo "Welcome to Open Operator installer!"
	case "$OSTYPE" in
	  darwin*)  install_on_mac ;;
	  linux*)   check_linux ;;
	  *)        bad_os_type ;;
	esac
}

main
