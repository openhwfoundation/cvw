QUESTA_HOME?=/cad/mentor/questa_sim-2023.4
CVW_GIT?=""

commandline:
	podman run -it --rm \
	-v cvw_temp:/home/cad/cvw \
	-v $(QUESTA_HOME):/cad/mentor/questa_sim-xxxx.x_x \
	--privileged --network=host \
	wallysoc/regression_wally /bin/bash

regression_openhw_cvw:
	podman run \
	-e CVW_GIT=$(CVW_GIT) \
	-e CLEAN_CVW=1 -e BUILD_ACT=1 -e RUN_QUESTA=1 \
	-v cvw_temp:/home/cad/cvw \
	-v $(QUESTA_HOME):/cad/mentor/questa_sim-xxxx.x_x \
	--privileged --network=host \
	--rm wallysoc/regression_wally

push_hub:
	podman push wallysoc/ubuntu_wally:latest
	podman push wallysoc/toolchains_wally:latest
	podman push wallysoc/regression_wally:latest

update_ubuntu:
	podman build -t wallysoc/ubuntu_wally -f Dockerfile.ubuntu .

update_toolchains:
	podman build -t wallysoc/toolchains_wally -f Dockerfile.builds .

update_regression:
	podman build -t wallysoc/regression_wally -f Dockerfile.regression .
