# OpenVINO-18.04-Support

Unofficial support scripts (hacks to be precise) modified by yours truly and @jameshi16

## How to use it

Replace the shell script `/opt/intel/computer_vision_sdk_2018.1.265/deployment_tools/inference_engine/share/InferenceEngineConfig.cmake` with the `InferenceEngineConfig.cmake` provided in this repository.

To test if you have sucessfully installed and configured OpenVINO on your host, replace the `demo_squeezenet_download_convert_run.sh` with the one provided in this repository at this location: `/opt/intel/computer_vision_sdk_2018.1.265/deployment_tools/demo`.

# Contributors

Nikhil Raghavendra (@nikhilraghava) and James Lim (@jameshi16).
