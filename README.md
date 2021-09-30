# Unofficial Ubuntu 18.04 Support for OpenVINO™

As of June 2018, OpenVINO™ only supports Ubuntu 16.04.3 LTS (64 bit), Windows 10 (64 bit) and CentOS 7.4 (64 bit). James Lim (@jameshi16) and I (@starhopp3r) have modified the `InferenceEngineConfig.cmake` to allow OpenVINO™ to run on Ubuntu 18.04 without any issues.

## How to use it

Replace the make file `/opt/intel/computer_vision_sdk_2018.1.265/deployment_tools/inference_engine/share/InferenceEngineConfig.cmake` with the `InferenceEngineConfig.cmake` provided in this repository.

To test if you have sucessfully installed and configured OpenVINO on your host, replace and run the `demo_squeezenet_download_convert_run.sh` with the one provided in this repository at this location: `/opt/intel/computer_vision_sdk_2018.1.265/deployment_tools/demo`.

# Contributors

Nikhil Raghavendra (@starhopp3r) and James Lim (@jameshi16).

Copyright © Intel Corporation. Licensed under the Apache License, Version 2.0.
