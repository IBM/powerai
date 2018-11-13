# Module to provide core functions for Vision API (vapi) tools
from __future__ import print_function
import os
import sys
import logging
import json
import requests
from urllib3.exceptions import InsecureRequestWarning


# Dictionary to hold config/setup informatin
cfg = {}

# Loads config info from heirarchy of possible locations
#  1) env var identifies the file
#  2) $HOME/vapi.cfg
#
# Returns 0 on success; 1 on failure
def loadCfgInfo(cfgFile=""):
    global cfg

    cfg["Auth"] = None;
    
    if (not cfgFile) and ("VAPI_CFG" in os.environ):
        cfgFile = os.environ["VAPI_CFG"]
        
    if (not cfgFile):
        cfgFile = os.environ["HOME"] + "/vapi.cfg"

    if (os.path.exists(cfgFile) and os.path.isfile(cfgFile)):
        
        with open(cfgFile) as json_cfg_file:
            try:
                cfg = json.load(json_cfg_file)
            except json.decoder.JSONDecodeError as de:
                eprint("ERROR: Syntax error in cfg file '{}';".format(cfgFile))
                eprint("    {}".format(de.args))
                return 1
                
        # Setup logging
        if "logLevel" in cfg:
            loglevel = cfg["logLevel"]
        else:
            loglevel = 40
            
        logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s',
                            datefmt='%H:%M:%S',
                            level=loglevel)

        # Make sure we have a server identified...
        # 'hostname' is the preferred approach.
        if "hostname" in cfg:
            cfg['baseUrl'] = "https://" + cfg['hostname'] + "/powerai-vision/api"
        elif "baseUrl" not in cfg:
            eprint("ERR: config file ({}) does not contain a `hostname`.",format(cfgFile))
            return 1
            
        # Setup for the approprite authentication
        if "VAPI_TOKEN" in os.environ:
            # ENV var overrides cfg file
            cfg['token'] = os.environ['VAPI_TOKEN']
        elif not "VAPI_TOKEN" in cfg:
            # If no VAPI_TOKEN info available, fall back to old style Auth
            if not "Auth" in cfg:
                if "auth" in cfg:
                    cfg["Auth"] = cfg["auth"]
                else:
                    # Fall back to no auth (this allows access to the old Tech Previews
                    pass

        # Disable warning messages about SSL certs 
        requests.packages.urllib3.disable_warnings()
        rc = 0
    else:
        eprint("Err: Could not find config file ({})".format(cfgFile))
        rc = 1
    return rc


#------------------------------------
# Eases printing to STDERR
def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


#------------------------------------
# Checks if result from Vision API succeeded
# (Current API returns failure indication in the JSON body)
def rspOk(rsp):
    logging.info("status_code: {}, OK={}.".format(rsp.status_code, rsp.ok))
           
    if (rsp.ok):
        try:
            jsonBody = rsp.json()
            if ("result" in jsonBody) and (jsonBody["result"] == "fail"):
                result = False
                logging.info(json.dumps(jsonBody, indent=2))
            else:
                result = True
        except ValueError:
            result = True
            logging.debug("good status_code, but no data")
    else:
        result = False
        
    return result


#-------------------------------------------------------------------
# Methods for Get, Post, and Delete
# These are the only HTTP  verbs currently supported
# by the Vision API. Methods are used to front-end
# the 'requests' methods to add common parameters
# such as certificate stuff and user authentication
# information
def get(url, headers=None, **kwargs) :
    # Setup appropriate authentication if any is present
    authInfo = None
    if "token" in cfg:
        if headers is None:
            headers = {}
        headers['X-Auth-Token'] = u'%s' % cfg['token']
    elif "Auth" in cfg:
        authInfo = tuple(cfg["Auth"])

    return requests.get(url, verify=False, headers=headers, auth=authInfo, **kwargs)


def post(url, headers=None, **kwargs) :
    # Setup appropriate authentication if any is present
    authInfo = None
    if "token" in cfg:
        if headers is None:
            headers = {}
        headers['X-Auth-Token'] = u'%s' % cfg['token']
    elif "Auth" in cfg:
        authInfo = tuple(cfg["Auth"])

    return requests.post(url, verify=False, headers=headers, auth=authInfo, **kwargs)


def delete(url, headers=None, **kwargs) :
    # Setup appropriate authentication if any is present
    authInfo = None
    if "token" in cfg:
        if headers is None:
            headers = {}
        headers['X-Auth-Token'] = u'%s' % cfg['token']
    elif "Auth" in cfg:
        authInfo = tuple(cfg["Auth"])

    return requests.delete(url, verify=False, headers=headers, auth=authInfo, **kwargs)
