#cloud-config

write_files:
- path: /etc/environment
  permissions: 0644
  content: |
    CONSUL_HOST=${consul_address}
    COREOS_PRIVATE_IPV4=$private_ipv4
    SLACK_WEBHOOK=${slack_webhook}
    DATADOG_API_KEY=${datadog_api_key}
coreos:
  units:
    - name: "task-schedule-add-node.service"
      command: "start"
      enable: true
      content: |
        [Unit]
        Description=Register Node to consul
        Wants=network-online.target
        After=network-online.target

        [Service]
        EnvironmentFile=/etc/environment
        Restart=on-failure
        ExecStart=/home/core/schedule-tasks.sh -t ${task_id} -r add

        [Install]
        WantedBy=multi-user.target

    - name: "task-schedule-remove-node.service"
      command: "start"
      enable: true
      content: |
        [Unit]
        Description=Remove Node from consul

        [Service]
        Type=oneshot
        RemainAfterExit=true
        EnvironmentFile=/etc/environment
        ExecStop=/home/core/schedule-tasks.sh -t ${task_id} -r remove

        [Install]
        WantedBy=multi-user.target

    - name: task-schedule.service
      command: start
      enable: true
      content: |
        [Unit]
        After=task-schedule-add-node.service
        Description=Run a scheduled tasks
        [Service]
        Type=oneshot
        EnvironmentFile=/etc/environment
        ExecStart=/home/core/schedule-tasks.sh -t ${task_id} -p ${task_period} -s ${task_command}

    - name: task-schedule.timer
      command: start
      enable: true
      content: |
        [Unit]
        Description=Timer for task-schedule
        [Timer]
        Persistent=true
        # every 15 mins *:0/15
        OnCalendar=*:0/1
        [Install]
        WantedBy=multi-user.target