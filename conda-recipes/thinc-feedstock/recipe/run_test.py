import os
import sys
import pytest
import thinc

PACKAGE_DIR = os.path.abspath(os.path.dirname(thinc.__file__))
sys.exit(pytest.main([PACKAGE_DIR]))
