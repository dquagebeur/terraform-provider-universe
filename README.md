Terraform Provider Multiverse
==================

You can use this provider instead of writing your own Terraform Custom Provider in the Go language. Just write your 
logic in any language you prefer (python, node, java, shell) and use it with this provider. You can write a script that
will be used to create, update or destroy external resources that are not supported by Terraform providers.

Maintainers
-----------

The MobFox DevOps team at [MobFox](https://www.mobfox.com/) maintains the original provider. 

This is the birchb1024 fork, maintained by Peter Birch.

Requirements
------------

-	[Terraform](https://www.terraform.io/downloads.html) 0.13
-	[Go](https://golang.org/doc/install) 1.15.2 (to build the provider plugin)

Building The Provider
---------------------

Clone repository to: `$GOPATH/src/github.com/birchb1024/terraform-provider-multiverse`

```sh
$ mkdir -p $GOPATH/src/github.com/mobfox; cd $GOPATH/src/github.com/mobfox
$ git clone git@github.com:birchb1024/terraform-provider-multiverse.git
```

Enter the provider directory and build the provider

```sh
$ cd $GOPATH/src/github.com/mobfox/terraform-provider-multiverse
$ make build
```

#Using the provider

Check the `examples/` directory

Here an example of a provider which creates a json file in /tmp and stores data in it. 
This is implemented in the hello-world example directory.


## Example TF

Here's a TF which creates three JSON files in /tmp.

```hcl
terraform {
  required_version = ">= 0.13.0"
  required_providers {
    multiverse = {
      source = "github.com/mobfox/multiverse"
      version = ">=0.0.1"
    }
  }
}
provider "multiverse" {
  executor = "python3"
  script = "hello_world.py"
  id_key = "filename"
  environment = {
    api_token = "redacted"
    // example environment
    servername = "api.example.com"
    api_token = "redacted"
  }
  computed = jsonencode([
    "created"])
}

resource "json-file" "h" {
  provider = multiverse // because Terraform does not scan local providers for resource types.
  executor = "python3"
  script = "hello_world.py"
  id_key = "filename"
  computed = jsonencode([
    "created"])
  data = jsonencode({
    "name": "Don't Step On My Blue Suede Shoes",
    "created-by" : "Elvis Presley",
    "where" : "Gracelands"
    "hit" : "yes"

  })
}

resource "json-file" "hp" {
  provider = multiverse // because Terraform does not scan local providers for resource types.
  data = jsonencode({
    "name": "Another strange resource",
    "main-character" : "Harry Potter",
    "nemesis" : "Tom Riddle",
    "likes" : [
      "Ginny Weasley",
      "Ron Weasley"
    ]
  })
}

resource "json-file" "i" {
  provider = multiverse // because Terraform does not scan local providers for resource types.
  data = jsonencode({
    "name": "Fake strange resource"
  })
}

output "hp_name" {
  value = "${jsondecode(json-file.hp.data)["name"]}"
}

output "hp_created" {
  value = "${jsondecode(json-file.hp.dynamic)["created"]}"
}

```

The statement 

```hcl-terraform
  provider = multiverse // because Terraform does not scan local providers for resource types.
```

Is required because Terraform does not scan local providers. See Terraform Issue [26659](https://github.com/hashicorp/terraform/issues/26659)

- When you run `terraform apply` the resource will be created / updated
- When you run `terraform destroy` the resource will be destroyed

#### Attributes

* `executor (string)` could be anything like python, bash, sh, node, java, awscli ... etc
* `script (string)` the path to your script or program to run, the script must exit with code 0 and return a valid json string
* `id_key (string)` the key of returned result to be used as id by terraform
* `data (string)` must be a valid JSON string
* `computed` - a list of field names which are dymanic, ie computed by the executor and should be ignored by TF plan
* `dynamic` - a JSON string generated by the provider containing the fields from the executor which have been identified in the provider`computed` list 

##### Output
* `resource (map[string])` the output of your script must be a valid json with all keys of type *string* in the form `{"key":"value"}`

#### Handling Dynamic Data from the Executor

The `data` field in the provider attributes is monitored by Terraform plan for changes becuase it's both a Required field.
Any changes are detcted ant put into plan. However your provider may generated attributes dynamically (such as the creation
date) of a resource. When you list these dynamic fields in the `computed` field in the provider configuration or resource blocks, 
multiverse moves these fields into the `dynamic` field. The `dynamic` field is marked 'Computed' and is ignored by Terraform plan. As follows:

```hcl-terraform
resource "json-file" "h" {
  provider = multiverse // because Terraform does not scan local providers for resource types.
  executor = "python3"
  script = "hello_world.py"
  id_key = "filename"
  computed = jsonencode(["created"])
  data = jsonencode({
      "name": "test-terraform-test-43",
      "created-by" : "Elvis Presley",
      "where" : "gracelands"
    })
}
```

After the plan is applied the tfstate file will then contain information:

```hcl-terraform
resource "json-file" "h" {
    computed = jsonencode(
        [
            "created",
        ]
    )
    data     = jsonencode(
        {
            created-by = "Elvis Presley"
            name       = "test-terraform-test-43"
            where      = "gracelands"
        }
    )
    dynamic  = jsonencode(
        {
            created = "21/10/2020 19:27:25"
        }
    )
}
```
 
In the executor script the `created` field is retuned just like the others. No extra handling is requried:

```python
if event == "create":
    # Create a unique file /tmp/hello_world.pyXXXX and write the data to it
    . . .
    input_dict["created"] = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
 
```

#### Referencing in TF template

This an example how to reference the resource and access its attributes

Let's say your script returned the following result
 
```json
{
  "id": "my-123",
  "name": "my-resource",
  "capacity": "20g"
}
```

then the resource in TF will have these attributes

```hcl
id = "my-123"
resource = {
  name = "my-resource"
  capacity = "20g"
}
```

you can access these attributes using variables

```
${multiverse_custom_resource.my_custom_resource.id} # accessing id
${multiverse_custom_resource.my_custom_resource.resource["name"]}
${multiverse_custom_resource.my_custom_resource.resource["capacity"]}
```

#### Why the attribute *data* is JSON?

This will give you flexibility in passing your arguments with mixed types. We couldn't define a with generic mixed types, 
if we used map then all attributes have to be explicitly defined in the schema or all its attributes have the same type.


# Writing an Executor Script

Your script must be able to handle the TF event and the JSON payload *data*

#### Input

* `event` : will have one of these `create, read, delete, update, exists`
* `data` : is passed via `stdin`

Provider configuration data is passed in these environment variables:

* `id` - if not `create` this is the ID of the resource as returned to Terraform in the create
* `script` -
* `id_key` - 
* `executor` -
* `script` -

Plus any attributes present in the `environment` section in the provider block.

Your script could look something like the hello-world example below. This script maintains files in the file system 
containing JSON data in the HCL. 

#### Output
The `exists` event expects either `true` or `false` onthe stdout of the execution. 
`delete` sends nothing on stdin and requires no output on stdout.
The other events require JSON on the standard output matching the input JSON plus any dynamic fields.
The `create` execution must have the id of the resource in the `id_key` field.


```python
import os
import sys
import json
import tempfile
from datetime import datetime

if __name__ == '__main__':
   result = None
   event = sys.argv[1] # create, read, update or delete, maybe exists too

   id = os.environ.get("filename")            # Get the id if present else None
   script = os.environ.get("script")

   if event == "exists":
      # ignore stdin
      # Is file there?
      if id is None :
          result = False
      else:
          result = os.path.isfile(id)
      print('true' if result else 'false')
      exit(0)

   elif event == "delete":
        # Delete the file
        os.remove(id)
        exit(0)

   # Read the JSON from standard input
   input = sys.stdin.read()
   input_dict = json.loads(input)

   if event == "create":
        # Create a unique file /tmp/hello_world.pyXXXX and write the data to it
        ff = tempfile.NamedTemporaryFile(mode = 'w+',  prefix=script, delete=False)
        input_dict["created"] = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
        ff.write(json.dumps(input_dict))
        ff.close()
        input_dict.update({ "filename" : ff.name}) # Give the ID back to Terraform - it's the filename
        result = input_dict

   elif event == "read":
        # Open the file given by the id and return the data
        fr=open(id, mode='r+')
        data = fr.read()
        fr.close()
        if len(data) > 0:
            result = json.loads(data)
        else:
            result = {}

   elif event == "update":
       # write the data out to the file given by the Id
       fu=open(id,mode='w+')
       fu.write(json.dumps(input_dict))
       fu.close()
       result = input_dict

   print(json.dumps(result))

```

To test your script before using in TF, just give it JSON input and environment variables. You can use the test harnesses
of your script language also.

```bash
echo "{\"key\":\"value\"}" | id=testid001 python3 my_resource.py create
```
## Renaming the Resource Type

In your Terraform source code you may not want to see the resource type `multiverse`. You might a 
better name, reflecting the actual resouce type you're managing. So you might want this instead:

```hcl-terraform
resource "spot_io_elastic_instance" "myapp" {
  provider = "multiverse"
  executor = "python3"
  script = "spotinst_mlb_targetset.py"
  id_key = "id"
  data = jsonencode({        
         // . . .
        })
}
```
The added `provider =` statement forces Terrform to use the the multiverse provider for the resource. 

We need to tell the provider which resource types it is providing to Terraform. By default the only resource type
it provides is the `multiverse` type. To enable other names set the environment variable 'TERRAFORM_MULTIVERSE_RESOURCETYPES' 
include the resource type names an a comma-seperated list such as 
```shell script
export TERRAFORM_MULTIVERSE_RESOURCETYPES='spot_io_elastic_instance,json-file,postgres-db'
```
## Multiple provider names
If you have duplicated the provider (see 'Renaming the Provider') then becuase the RESOURCETYPES variable name is of the form:
`TERRAFORM_{providername upper case}_RESOURCETYPES` you can use the new name. Such as `TERRAFORM_ALPHA_RESOURCETYPES`


## Configuring the Provider

Terraform allows [configuration of providers](https://www.terraform.io/docs/configuration/providers.html#provider-configuration-1), 
in a `'provider` clause. The multiverse provider also has configuration where you specify the default executor, script and id fields.  
An additional field `environment` contains a map of environment variables which are passed to the script when it is executed. 

This means you don't need to repeat the `executor` nad `script` each time the provider is used.  You can 
override the defaults in the resource block as below.

```hcl-terraform
provider "alpha" {
  environment = {
    servername = "api.example.com"
    api_token = "redacted"
  }
  executor = "python3"
  script = "hello_world.py"
  id_key = "id"
}

resource "alpha" "h1" {
  data = jsonencode({
      "name": "test-terraform-test-1",
    })
}

resource "alpha" "h2" {
  script = "hello_world_v2.py"
  data = jsonencode({
      "name": "test-terraform-test-2",
    })
}

```

## Renaming the Provider

You can rename the provider itself. This could be to 'fake out' a normal provider to investigate its behaviour or 
emulate a defunct provider. This can be achieved by copying or linking to the provider binary file with a 
name inclusive of the provider name:

```shell script
 # Move to the plugins directory wherein lies the provider
cd ~/.terraform.d/plugins/github.com/mobfox/alpha/0.0.1/linux_amd64
# Copy the original file
cp terraform-provider-multiverse  terraform-provider-spot_io_elastic_instance
# or maybe link it
ln -s terraform-provider-multiverse  terraform-provider-spot_io_elastic_instance
```

Then you need to configure the provider in your TF file:

```hcl-terraform
terraform {
  required_version = ">= 0.13.0"
  required_providers {
    spot_io_elastic_instance = {
      source = "github.com/mobfox/spot_io_elastic_instance"
      version = ">=0.0.1"
    }
  }
}
```
How does this work? The provider extracts the name of the resource type 
from its own executable in the plugins directory. By default the multiverse provider sets the default resource type
to the same as the provider name.  

## Developing the Provider


If you wish to work on the provider, you'll first need [Go](http://www.golang.org) installed on your machine (version 1.15.2+ is *required*). You'll also need to correctly setup a [GOPATH](http://golang.org/doc/code.html#GOPATH), as well as adding `$GOPATH/bin` to your `$PATH`.

 > A good IDE is always beneficial. The kindly folk at [JetBrains](https://www.jetbrains.com/) provide Open Source authors with a free licenses to their excellent [Goland](https://www.jetbrains.com/go/) product, a cross-platform IDE built specially for Go developers   

To compile the provider, run `make build`. This will build the provider and put the provider binary in the workspace directory.

```sh script
$ make build
```

In order to test the provider, you can simply run `make test`.

```sh
$ make test
```

To install the provider in the usual places for the `terraform` to use run make install. It will place it the plugin directories:

```
$HOME/.terraform.d/
└── plugins
    ├── github.com
    │   └── mobfox
    │       ├── alpha
    │       │   └── 0.0.1
    │       │       └── linux_amd64
    │       │           └── terraform-provider-alpha
    │       └── multiverse
    │           └── 0.0.1
    │               └── linux_amd64
    │                   ├── terraform-provider-alpha
    │                   └── terraform-provider-multiverse
    ├── terraform-provider-alpha
    └── terraform-provider-multiverse
```



Feel free to contribute!
