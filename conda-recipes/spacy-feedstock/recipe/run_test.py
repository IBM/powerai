import os
import sys
import pytest
import spacy

PACKAGE_DIR = os.path.abspath(os.path.dirname((spacy.__file__)))
sys.exit(pytest.main([PACKAGE_DIR]))
