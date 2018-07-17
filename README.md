# Distributed Task Scheduler

A distributed and highly available task scheduler built using
[Consul](https://www.consul.io/), [CoreOS](https://coreos.com/), and [systemd](https://www.freedesktop.org/wiki/Software/systemd/). It's similar in concept to
cron but it is a system service that is distributed on any number of servers.
Design inspired by the google whitepaper [Reliable Cron across the Planet](https://queue.acm.org/detail.cfm?id=2745840).

## Goal
- Run a task at a set interval of time
- Run the task on any number of servers but do not run on more then 1 server at
  a time (no overlapping runs)
- Must not run more than one instance of the task at a time or on the same server
- Log journald a syslog type local logging
- Provide an optional flag to notify Slack when a task starts, the server it is
  running on, and when it finished
- Provide an optional flag to send a task duration metric to DataDog

## Consul
Right now the project will bring up a dev instance of Consul that saves keys in-memory
and is only running in one node.  For production I would like to get this running
on [Consul as a service mesh](https://www.hashicorp.com/blog/consul-1-2-service-mesh)
with TLS encryption and identity-based authorization. Data will also be stored
on persistent disks. The task scheduler service is already accessing consul over
an Application Load Balancer so we could put any number of consul instances
behind that to make it highly available.

## Quick start

To change the AWS region and Coreos AMI image edit.
`terraform/modules/global_variables/vars.tf`. If you change the region you
will have to update the Coreos AMI image to match. Default region is set to "us-east-2"

Edit the file `terraform/nodes/vars.tf` to configure the service:
- Server name
- The number of nodes
- Instance type
- Task period
- Task command
- Timer mins
- Slack Webhook
- DataDog API Key

Once you have made your modifications run this script to use Terraform to bring
up the infrastructure
```
./scripts/create.sh
```

The script will create a new VPC, a Consul instance, and a number of nodes.  They
are separated in Terraform so you can bring up each set of infrastructure for testing.

## Clean up
To tear everything down run
```
./scripts/cleanup.sh
```

## Debugging
To view or debug the service log into any of the CoreOS nodes

```
ssh -i ~/.ssh/mp-ssh-key core@<coreos node ip>
```

View task-schedule  logs
```
journalctl -u task-schedule -xfe
```

Stop the task-schedule service
```
sudo systemctl stop task-schedule.service
```

Start the task-schedule service
```
sudo systemctl start task-schedule.service
```

Access consul UI
go to `http://<consul public ip>:8500/`

## Local usage for testing
Setup environment variables
```
export CONSUL_HOST=<public ip of consul>
export SLACK_WEBHOOK=<your slack webhook>
export DATADOG_API_KEY=<your datadog api key>
```

Register your local machine to consul with a test task id
```
./scripts/schedule-tasks.sh -t test -r add
```

Example on how to manual run your task so it can't run more than once in a 5
second period.
```
./scripts/schedule-tasks.sh -t task -p 5 echo 'Hello World'
```

Set a timer or cron job to be lower than the requested period to ensure your task
runs.  For example if you want to make sure your job runs no more then once an
hour set your period (-p) to 3600 and your timer or job to run schedule-tasks.sh
every 10, 15, or 30 mins. This can be any value as long as it is less than 1 hour.

---

## TODO
- Convert the bash script to a Go app
- Lock down consul UI and API access
- Switch out Consul to run a service mesh

