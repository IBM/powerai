# vapi-tools CLI
This set of tools is a collection of tools developed to drive the *PowerAI Vision API* for test
purposes. Each tool is small and directed at a specific API endpoint. Since testing the API
endpoints was the primary purpose of the tools, most have very little if any validation of inputs
and the "_create_" tools usually require JSON for the input. This approach was chosen so that
it would be easy to drive invalid input to the endpoints and to provide raw JSON to validate
endpoint output.

Unfortunately, this approach does not make them very user friendly. Not only are parameters
not validated, but tools are not task based. For example, deplopyed models are
manipulated/managed via the `*WebApi` tools. To deploy a model, the `createWebApi` tool is used. 

Even though the tools have usability shortcomings, they are being shared at this time to provide
examples of how the API can be accessed using Python.

The API documentation is included in this repo in the file `vision/docs/powerai-vision-api.html` or
at [this Link](http://htmlpreview.github.io/?https://github.com/IBM/powerai/blob/master/vision/doc/powerai-vision-api.html)
to get the rendered html.

# Usage
## Setup
The tools require the Python `requests` package. Other than that, all other packages are part
of the base Python installation.

You must set `PYTHONPATH` to include the directory containing `vapi_core.py` as this file is
imported by all commands.

## Configuration
There are 2 required pieces of configuration -- one for the server hosting _PowerAI Vision_ and
one for user authentication information.

In release 1.1.1.0 mutli-user support was added. This capability requires a token be passed
instead of user authentication. The token can be obtained via the `getVisionTokenPass`
command. Once obtained, the token must be saved in the exported environment variable `VAPI_TOKEN`.

The toolset is setup to look for the `VAPI_TOKEN` environment variable first. If found,
the toolset will use the multi-user authentication method. If the `VAPI_TOKEN` is not set,
the toolset will look for the authentication information in the config file described below.

A JSON config file is used to obtain the server information (as well as other optional
configuration information). The config file provides the following information:

*    **hostname**  -- identifies the powerai-vision server to contact. This parameter is required.
*    **Auth**      -- used for release 1.1.0.0 authentication
*    **logLevel**  -- indicates the level of logging detail. See the _Logging_ section below for
  more details.
  
For example:

```
{
    "hostname" : "powerai-vision-server.mycompany.com",
    "Auth"    : [ "user1", "MyPassw0rd" ],
    "logLevel": 40
}
```

Note that the attribute for authentication information is Capitalized and will only be used
if the `VAPI_TOKEN` environment variable (described previously) is not found.

The file path to the config file can be identified via the `VAPI_CFG` environment variable or the file 
`$HOME/vapi.cfg` is the default file path. Use of the envirnment variable makes it easier to access different
_PowerAI Vision_ Servers.

## Logging
The tools use the Pthon logging facility. The level is controled via an optional field in the 
`VAPI_CFG` file. This field is `logLevel` and values must be numeric.

  * DEBUG -- 10
  * INFO  -- 20
  * WARN  -- 30
  * ERROR -- 40
  * CRITICAL -- 50 (this level is not used in the tools)

Currently logging goes to STDERR which can be redirected on the command line.

Note that to see more details about the interaction the API endpoints, setting `logLevel` to `10`.

## Input Limitations for Creating Objects
In the current form, each "_create_" command requires a JSON string as input. This string
contains the information to be sent to the API. This approach was chosen because it was
the easiest to code in Python and it also allows a way to provide invalid input with
which to test the API.

Note that for some of the commands, argument flags are now supported.
Try the command with no parameters or with `--help` to get a usage statement.

# Tools of Special Note
## getVisionTokenPass
`getVisionTokenPass` is the tool that will get an access token given a user name
and password as input. As mentioned previously, a token is required to access the
_PowerAI Vision_ API endpoints in versions 1.1.1.0 and later. 

## Inference Tools
More information and documentation on doing inferences is being worked. For now, the best
example for inferences is the `classify_dir` script which will classify all images in a given
directory and summarize the results into a CSV file.

An object detection script will be added in the future.

## eventMonitor
`eventMonitor` can be used to monitor the SSE events for a particular user.
With the introduction of multi-user support in version 1.1.1.0, events are generated 
on a user by user basis such that "_userA_" will not see "_userB_"'s events and vice
versa.

# Non-API Commands
## cleanPropJson
This command can be used to cleanup the `prop.json` file found in dataset export zip files.

# Examples
## create a dataset
```
user@my-mac:~/projects/vision/tools$ ./createDataset '{"name":"newDataset", "scenario":"other"}'
{
  "dataset_id": "cd020043-852c-4452-af36-8ec411bb9aa7", 
  "result": "success"
}
```

## get list of datasets
```
user@my-mac:~/projects/vision/tools$ ./getDatasets
[
  {
    "locked": 0, 
    "name": "Carls new Dataset", 
    "scenario": "bcarl Test", 
    "created_at": 1519423636017, 
    "total_file_count": 0, 
    "updated_at": 1519423636017, 
    "owner": "admin", 
    "usage": "generic", 
    "_id": "fc57acb4-1a05-4cc6-9998-0ec48d7f5724", 
    "type": 0
  }, 
  {
    "locked": 0, 
    "name": "newDataset", 
    "scenario": "bcarl Test", 
    "created_at": 1519423218372, 
    "total_file_count": 0, 
    "updated_at": 1519423259434, 
    "owner": "admin", 
    "usage": "generic", 
    "_id": "cd020043-852c-4452-af36-8ec411bb9aa7", 
    "type": 0
  }
]
```

## Upload a File
There are 2 ways to upload files. Using `uploadFile` allows uploading a single file.
This tool was the original written to do uploads. The second method is `uploadFiles`.
It supports uploading multiple files at a time. Both of these tools now support
input args.

Sample usage:

```
user@my-mac:~/projects/vision$ uploadFiles --help
usage: uploadFiles [-h] --dsid DSID [--catid CATID] [--catname CATNAME]
                   filepaths [filepaths ...]

Tool to upload files to powerai vision

positional arguments:
  filepaths          space separated list of paths to upload.

optional arguments:
  -h, --help         show this help message and exit
  --dsid DSID        ID of the dataset to upload into
  --catid CATID      ID of the category to which the file belon
```

`uploadFiles` example:

```
user@my-mac:~/projects/vision/tools$ ./uploadFiles --dsid fc57acb4-1a05-4cc6-9998-0ec48d7f5724 $HOME/projects/vision/images/IMG_0023.jpg
{"result":"success","id":"5f6b2958-c0d6-47b0-a053-ecb1a6927650","dataset_id":"fc57acb4-1a05-4cc6-9998-0ec48d7f5724"}
```

## Change File Category

```
user@my-mac:~/projects/vision/tools$ ./chgFileCategory fc57acb4-1a05-4cc6-9998-0ec48d7f5724 5f6b2958-c0d6-47b0-a053-ecb1a6927650 37d390a9-d975-4e25-accf-c9c8bb22fea3
{
  "dataset_id": "fc57acb4-1a05-4cc6-9998-0ec48d7f5724", 
  "category_id": "37d390a9-d975-4e25-accf-c9c8bb22fea3", 
  "result": "success", 
  "id": "5f6b2958-c0d6-47b0-a053-ecb1a6927650"
}
```

## Listing Files
Listing files is done via the `getFiles` script. Different data will
be included in the resulting json depending upon the type of file
(e.g. video files, photos, video frames).

```
user@my-mac:~/projects/vision/tools$ ./getFiles fc57acb4-1a05-4cc6-9998-0ec48d7f5724
[
  {
    "category_id": "", 
    "file_name": "5f6b2958-c0d6-47b0-a053-ecb1a6927650.jpg", 
    "created_at": 1519424311974, 
    "label_file_key": "fc57acb4-1a05-4cc6-9998-0ec48d7f5724IMG_0023", 
    "meta_data": {
      "width": 1600, 
      "height": 1200
    }, 
    "dataset_id": "fc57acb4-1a05-4cc6-9998-0ec48d7f5724", 
    "_id": "5f6b2958-c0d6-47b0-a053-ecb1a6927650", 
    "category_name": ""
  }
]
```

## Saving Labels
When saving labels to a file, _PowerAI Vision_ requires that all labels associated with
the file be specified in the save operation. In other words, _PowerAI Vision_ cannot
"_add_" one or more labels to an existing set of labels. 

This requirement means that if one wants to add an additional label to an existing set,
they have perform the following sets

 1. Get the current labels for the file from _PowerAI Vision_ (via `getFileLabels`).
 2. Add the new label(s) to that returned set of labels (either via a script or
 hand editing the returned data.
 3. Save the now complete set of labels back to _PowerAI Vision_ (via `saveFileLabels`).
 Note that only the array of labels need be in the file passed to `saveFileLabels`.
 
### Getting file labels

```
$ ./getFileLabels b0e03bdf-3bf1-4927-9753-a8b9ecaaebba "0c0a0dbb-6bbb-4917-83f2-39fada2c092c"

{
  "_id": "00fedee0-6d5b-493b-adec-43a0d8b0b021",
  "created_at": 1534226686220,
  "dataset_id": "b0e03bdf-3bf1-4927-9753-a8b9ecaaebba",
  "label_file_key": "0c0a0dbb-6bbb-4917-83f2-39fada2c092c",
  "labels": [
    {
      "name": "white car",
      "bndbox": {
        "xmin": 596,
        "ymin": 221,
        "xmax": 757,
        "ymax": 342
      },
      "generate_type": "manual"
    },
    {
      "name": "black car",
      "bndbox": {
        "xmin": 312,
        "ymin": 192,
        "xmax": 439,
        "ymax": 284
      },
      "generate_type": "manual"
    }
  ]
}
```

### Updating the label list
Edit the saved labels to add (in this case) the new label(s). The resulting file should should
only contain the label array as shown below.

```
 [
    {
      "name": "white car",
      "bndbox": {
        "xmin": 596,
        "ymin": 221,
        "xmax": 757,
        "ymax": 342
      },
      "generate_type": "manual"
    },
    {
      "name": "black car",
      "bndbox": {
        "xmin": 312,
        "ymin": 192,
        "xmax": 439,
        "ymax": 284
      },
      "generate_type": "manual"
    }
    {
      "name": "black car",
      "bndbox": {
        "xmin": 500,
        "ymin": 200,
        "xmax": 600,
        "ymax": 250
      }
    } 
]
```

### Saving the updated label list
Use the `saveFileLabels` tool to save the modified label list.

```
$ ./saveFileLabels --ds  b0e03bdf-3bf1-4927-9753-a8b9ecaaebba --file "0c0a0dbb-6bbb-4917-83f2-39fada2c092c" --lab /tmp/labels
{
  "result": "success"
}
```

### Checking that the labels are saved
For peace of mind, you can get the labels again to ensure that they have been updated.

```
16:51 $ ./getFileLabels b0e03bdf-3bf1-4927-9753-a8b9ecaaebba "0c0a0dbb-6bbb-4917-83f2-39fada2c092c"
{
  "_id": "00fedee0-6d5b-493b-adec-43a0d8b0b021",
  "created_at": 1534226686220,
  "dataset_id": "b0e03bdf-3bf1-4927-9753-a8b9ecaaebba",
  "label_file_key": "0c0a0dbb-6bbb-4917-83f2-39fada2c092c",
  "labels": [
    {
      "name": "white car",
      "bndbox": {
        "xmin": 596,
        "ymin": 221,
        "xmax": 757,
        "ymax": 342
      },
      "generate_type": "manual"
    },
    {
      "name": "black car",
      "bndbox": {
        "xmin": 312,
        "ymin": 192,
        "xmax": 439,
        "ymax": 284
      },
      "generate_type": "manual"
    },
    {
      "name": "black car",
      "bndbox": {
        "xmin": 500,
        "ymin": 200,
        "xmax": 600,
        "ymax": 250
      },
      "generate_type": "manual"
    }
  ]
}
```

# TODOS
1. Add command line parameter processing to ease creation of objects and to allow the use
   of object names instead of IDs.
2. Add the ability to better manage the logging facility in the config file.
2. Add more base commands to cover each of the operations available on each of the
   API endpoints.
3. Create an API library that can be used to build more complex operations
4. Add more complex operations (e.g. object dection on a directory of files,
   or a multiple stage inference example)
5. Develop basic test suite for the API.

# Suggestions and Getting Help
Suggestions and recommendations are welcome. Please use Git Hub issues on the 
[powerai repo](https://github.com/IBM/powerai/issues) to report suggestions, recommendations, and problems.
