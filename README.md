# BAD - Build and Deploy

This repository contains a number of scripts and configurations to build a Ruby Sinatra
application (the app), create a base AMI and provision it as an AWS EC2 instance.

> In fact it's able to build almost any ruby app. Extending it to build other frameworks and
> languages is trivial.

The build and deploy tool ("bad" for short) is delivered as an standalone docker image.

Users suply the source code repository and the name of the output image so *bad* creates
an application docker image and executes it on EC2.

    [ source code + image name ] ---> [ bad ] ---> [ app container/EC2 ]


# Dependencies

From the user POV, this tool depends on:

- Docker

- AWS Credentials & Key Pair (SSH)

- The SSH private key file


# Building Bad

> This step needs to be done only once

To create the *bad* tool on your local machine, execute:

    $ git clone https://github.com/caruccio/bad
    $ cd bad
    $ sudo docker build . -t bad

A new image *bad* is created:

    $ sudo docker images bad

Execute for help:

    $ sudo docker run -it --rm bad
    Usage: docker run [ENV-PARAMS] [VOLUME-PARAMS] [BAD-IMAGE-NAME] [APP-IMAGE-NAME]

    Where:

        - ENV-PARAMS
            -e AWS_ACCESS_KEY_ID=XXXXXXXXX
            -e AWS_SECRET_ACCESS_KEY=XXXXXXXXX
            -e AWS_DEFAULT_REGION=XXXXXX

        - VOLUME-PARAMS

            -v <PATH-TO-SOURCE-ROOT-DIR>:/src
            -v <PATH-TO-SSH-PRIVATE-KEY>:/ssh-private-key
            -v <PATH-TO-DOCKER-SOCKET>:/var/run/docker.sock
            -v <PATH-TO-DOCKER-CONFIG-DIR>:/bad/.docker

        - BAD-IMAGE-NAME

            Usually "bad"

        - OUTPUT-IMAGE-NAME

            docker-account/app-image-name:tag

    Example usage:

        $ sudo docker run \
            -e AWS_ACCESS_KEY_ID=XXXXXXXXXXXXXXX \
            -e AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXXXXX \
            -e AWS_DEFAULT_REGION=us-east-1 \
            -v /path/to/simple-sinatra-app/:/src \
            -v $HOME/.ssh/id_rsa:/ssh-private-key \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v $HOME/.docker/:/bad/.docker \
            -it --rm \
            bad \
            caruccio/ssa:1.0


# Setup AWS credentials

> This step needs to be done only once

Export your AWS credentials to environment. Grab the values from [security credentials
page](https://console.aws.amazon.com/iam/home?#/security_credential):

    $ export AWS_ACCESS_KEY_ID=<ACCESS_KEY_ID>
    $ export AWS_SECRET_ACCESS_KEY=<SECRET_ACCESS_KEY>

If you didn't uploaded your SSH _public_  key to AWS, do it now from [Key Pairs on AWS
console](https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#KeyPairs:sort=keyName).

> The file is usually `$HOME/.ssh/id_rsa`.

Export full path of your SSH _private_ key file to env var `AWS_PRIVATE_KEY_FILE`:

    $ export AWS_PRIVATE_KEY_FILE=$HOME/.ssh/id_rsa


# App Server AMI

> This step needs to be done only once

App Server is a basic AMI EBS backed volume used to spinup docker containers of your sinatra app.

**Any already existing AMI named "BAD - AppServer" will be destroyed**

    $ sudo docker run \
        -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
        -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
        -e AWS_DEFAULT_REGION=us-east-1 \
        -v ${AWS_PRIVATE_KEY_FILE}:/ssh-private-key \
        -it --rm \
        bad \
        build-ami

> Feel free to select another region in `AWS_DEFAULT_REGION` variable

After several minutes, a new AMI named `BAD - AppServer` will be available on your
[AMIs AWS console](https://console.aws.amazon.com/ec2/v2/home?#Images).


# Build and deploy the Sinatra app

Source code of the app is provided to builder container via volume mapping of local dir
`/fullpath/to/simple-sinatra-app` to container dir `/src`.

In order to push the app image to docker registry, we also need to expose both `/var/run/docker.sock`
and docker credentials `$HOME/.docker` inside de container.

> Make sure you are logged into docker hub (just run `docker login`).
> Change the image name below (`caruccio/ssa:1.0`) to fit your docker account.
> Note the region **MUST** match the same region you created the AMI in the previous step.

OK, let's build the app and deploy it on EC2:

    $ git clone https://github.com/rea-cruitment/simple-sinatra-app
    $ sudo docker run \
        -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
        -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
        -e AWS_DEFAULT_REGION=us-east-1 \
        -v $PWD/simple-sinatra-app:/src \
        -v ${AWS_PRIVATE_KEY_FILE:-$HOME/.ssh/id_rsa}:/ssh-private-key \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /root/.docker/:/bad/.docker \
        -it --rm --privileged \
        bad \
        caruccio/ssa:1.0

> This command may takes several minutes to complete.

The address of the EC2 instance is shown at the end:

    Outputs:

    Instance Address = XXX.XXX.XXX.XXX

Access the application and profit!

    $ curl XXX.XXX.XXX.XXX
    Hello World!


# Rationale


## Assumptions

- The service is exposed directly to the internet, i.e. no load balancer

- Application is disposable, i.e. instead update the instance, we always create a new AMI and re-deploy it as a new EC2

- Minimal interface - only code & credentials

- Updating the running application (a.k.a. deploy strategy) is not properly addressed (not downtime-safe)

- Developer whants to test its app locally

- Code testing is out of scope. They are up to the developer implement and run


## Choosen Technologies

- Docker: encapsulation, portability, dependency-free usage

- Source-to-Image: easy app build, dev lifecycle support (assemble & run)

- Packer and Terraform: Easy to use, declarative language. Cross provider support.

- Ansible: Broadly adopted, declarative language, easily extensible and rich ecosystem


## Architecture

The project is split into 3 main stages


### Stage: BuildApp - Docker + S2I

Creates local docker image of the ruby application and pushes it to a central repository.

By making use of [source-to-image (S2I)](https://github.com/openshift/source-to-image) we can easily
build app images from source code. Since *bad* has access to the local docker, the image is available
to the host OS. Users are able to execute the app container as easily as `docker run <name>`.

Extending *bad* is just a matter of detecting the language of the code and providing source-to-image with the
correct builder image (see file `bin/build-docker-image`)

Docker pushes the image to a central registry (usually docker hub)

### Stage: BuildAMI - Packer + Ansible

The AMI volume is only a basic OS environment used to create EC2 instances running the
user app container. I could have delivered the app container directly inside the AMI's `/var/lib/docker`,
however by using the former we gain:

**Faster EC2 provisioning:** since the update process of the Operating System (yum) tends to last too long,
by puting it on a pre-built image will save us some time when instaciating EC2s.

**Faster end-2-end deployment:** Users needs to build the AMI only once, or when an update must be applied
to the OS.

**Setup docker storage with better volume backend:** Since AMi does not holds the `/var/lib/docker`, it can use
another docker storage backend (more on next section).

**Generic runtime:** a generic execution environment allows us to leverage any kind of workload where docker runs.

The tool is not ready to deal with multiple AMIs. It must to destroy the latest in oder to create a new, updated AMI.

### Stage DeployApp - Terrafom + Ansible

Starts an EC2 instance from AMI volume and runs the app's docker image.

Default docker storage backend (loopback) is not recomended for production environment because it's [too
slow](https://www.projectatomic.io/blog/2015/06/notes-on-fedora-centos-and-docker-storage-drivers/).
In order to use a better volume backend (devicemapper) the image must not be shipped with `/var/lib/docker`.
Instead, during EC2 provisioning we ask Terraform to attach an EBS into `/var/lib/docker`, then use Ansible
to configure docker to use that EBS as the backend. Ansible also starts the application to starts to serve requests.

The app is initiated as a daemon docker container, with cpu and memory constraints. This is so to prevent
resources exhasution by capping CPU and memory of the container (see file `terraform/ansible/roles/appserver/tasks/main.yaml`,
task `Start app container`). If the app dies, dockers restart it automatically.

Server is reacheable only on ports 80 (the service) and 22 (SSH)

### Issues

The security attack surface could be smaller if we avoid exposing SSH port to internet by using a bastion/jump host.

Docker client needs root access to connect to local docker daemon, which makes this method not suitable for CI/CD tools
like Jenkins. That could be mitigated replacing docker client and daemon with tools like
[buildah](https://github.com/projectatomic/buildah), [skope](https://github.com/projectatomic/skopeo) and
[runc](https://github.com/opencontainers/runc).

The `--privileged` flag is necessary for containers to access `/root/.docker/config.json` if its permissions are
too restritive (0700 for instance).

Web applications should run under an application server, like puma, instead being directly exposed to internet.
App servers are better designed to deal with concurrency and high load.


### Data flow diagram


```
·---·                          +===+
|   | = Input/Output           |   | = Processe
·---·                          +===+



     ·---------·
     | App Src |---------+
     ·---------·         |     += BuildApp ===+     ·------------·     +==========+
                         +---> | S2I + Source |---> | App Image  |---> | Registry |
 ·------------·          |     +==============+     ·------------·     +==========+
 | AWS SSH Key |---------+                                                  |
 ·-------------·                                                            |
                                                                            |
                                                                            V
 += BuildAMI =======+          ·---------·                   += DeployApp =========+
 | Packer + Ansible |--------> | OS AMI  |-----------------> | Terraform + Ansible |
 +==================+          ·---------·                   +=====================+
                                                                        |
                                                                        |
                                                                        |
                                                                        V
                                                                ·--------------·
                                                                | EC2 Instance |
                                                                ·--------------·
```


## Repo structure

```
$ tree
.
├── README.md
├── Dockerfile                    # Dockerfile to build *bad*
├── build-and-deploy.sh           # *bad* main
├── bin                           # image related scripts
│   ├── build-docker-image        # given a souce dir, creates a app docker image
│   ├── container-entrypoint      # entry point for *bad*
│   ├── find-ami-id               # helper
│   ├── find-key-name             # helper
│   ├── install-deps.sh           # helper
│   ├── push-docker-image         # send app docker image to rgistry
│   └── support.sh                # helper
├── packer                        # AMI related files
│   ├── ansible                   # update and install SO packages
│   │   ├── playbook.yaml
│   │   └── roles
│   │       └── appserver
│   │           ├── tasks
│   │           │   └── main.yaml
│   │           └── templates
│   │               ├── ami-tools.sh
│   │               └── docker-storage-setup
│   ├── build.sh                  # entry point
│   └── template.json             # Packer config template
└── terraform                     # Prvisioning related files
    ├── ansible                   # setup docker and stats the service
    │   ├── playbook.yaml
    │   └── roles
    │       └── appserver
    │           └── tasks
    │               └── main.yaml
    ├── deploy.sh                 # entry point
    └── deploy.tf                 # Terraform infrastructure configs
```

# This tool was tested with:

    $ uname -a
    Linux 6feb04efd992 3.10.0-327.36.3.el7.x86_64 #1 SMP Mon Oct 24 16:09:20 UTC 2016 x86_64 Linux

    $ uname -a
    Linux 2b18b61dea20 4.4.41-moby #1 SMP Thu Jan 12 13:03:58 UTC 2017 x86_64 Linux

    $ terraform --version
    Terraform v0.9.11

    $ packer --version
    1.0.3

    $ ansible --version
    ansible 2.3.0.0

    $ docker --version
    Docker version 17.05.0-ce, build v17.05.0-ce

    $ python --version
    Python 2.7.13

    $ pip --version
    pip 9.0.1 from /usr/lib/python2.7/site-packages (python 2.7)

    $ s2i version
    s2i v1.1.7
