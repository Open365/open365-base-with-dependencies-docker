#!/usr/bin/env python3

import os
import json
import subprocess


# COMMAND_TO_EXECUTE is an envar that should have a JSON-encoded array
# consisting of [command, param1, param2, ...]
command = json.loads(os.environ['COMMAND_TO_EXECUTE']);

print("Going to execute " + str(command))
subprocess.check_call(command)
