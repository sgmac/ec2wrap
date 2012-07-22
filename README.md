## ec2wrap 

Yet another wrapper to manage your EC2 instances. Before starting to tinker with libraries such as _boto_ or _fog_, I decided to give EC2 tools a try and boost my bash skills on the way. 

![listing](https://s3-eu-west-1.amazonaws.com/sgmac-images/listing.jpg)

My workflow with EC2 it's pretty straightforward. I just create instances using either a puclic AMI or an AWS AMI, running a specific service such as Memcache,PostgreSQL or Chef server. Unit testing is present as an example. I used [roundup](https://github.com/bmizerany/roundup), but I barely completed four tests, although I would like to have one test for each of the functions I have.

### Usage

```bash
ec2wrap.sh
usage: ec2wrap.sh [OPTIONS] cmd
      -h,--help                         Show this menu.
      -a,--alias                        Set alias for an instance.
      -g,--group                        Security group (default).
      -k,--keypair                      Keypair.
      -m,--ami                          Bootstrap selected AMI.
      -n,--multiple-instances           Clone 'n' times the same configuration.
      -z,--zone                         Availability zone for the instance.
      -t,--instance-type                Instace type.
      -i,--id                           Instance ID.
      aliases                           List aliases for instances.
      clone                             Clone instance using tags.
      create                            Create a new instance.
      kill                              Terminate an instance.
      list                              List instances.
      start                             Start an instance.
      stop                              Stop an instance.
      update                            Run manual update.
```

If you create a new instance, assign an alias, next time just clone the alias

```bash
ec2wrap.sh  create -m  ami-6996931d -g default  -k mykeypair.pem -t t1.micro -z eu-west-1a  --alias=centos62
```

Clone your instance using the above alias
```bash
ec2wrap.sh clone -a centos62
``` 
It's also possible to clone and modify some of the attributes, such as group, zone or instance type. 
```bash
ec2wrap.sh clone -a centos62 -t m1.small
```

You might need to create several instances of the same alias, in the next example I create three instances using the 
**memcache** alias.

```bash
ec2wrap.sh clone -a memcache -n 3
```
If you are familiar with EC2, you already know that when starting or stopping instances your public dns changes. I managed to add a host definition to the  _/.ssh/config_ using the instance ID. Every time you start the instance the file is updated with the new public dns. 

```bash
ec2wrap.sh start -i i-cb80ea83 
```
Log in your instance:
```bash
ssh i-cb80ea83

```
### MIT License 

Copyright (C) 2012 by Sergio Galván

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
