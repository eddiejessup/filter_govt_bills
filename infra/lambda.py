import boto3
import os


def lambda_handler(event, context):
    print("Got event: {}".format(event))

    print("Parsing environment variables")
    DOMAIN = os.environ["DOMAIN"]
    print("Updating domain: {}".format(DOMAIN))
    HOSTED_ZONE_ID = os.environ["HOSTED_ZONE_ID"]
    print("Using records in hosted zone: {}".format(HOSTED_ZONE_ID))

    if event["detail"]["lastStatus"] == "RUNNING":
        print("Got task-running event")

        containers = event["detail"]["containers"]
        assert len(containers) == 1
        task_arn = containers[0]["taskArn"]
        print("Got task ARN: {}".format(task_arn))

        print("Getting ECS client")
        ecs = boto3.client("ecs")

        print("Getting task network interface ID")
        task_response = ecs.describe_tasks(
            cluster=event["detail"]["clusterArn"], tasks=[task_arn]
        )
        task = task_response["tasks"][0]
        attachment_details = task["attachments"][0]["details"]
        network_interface_ids = [
            e["value"] for e in attachment_details if e["name"] == "networkInterfaceId"
        ]
        assert len(network_interface_ids) == 1
        network_interface_id = network_interface_ids[0]
        print("Got network interface ID: {}".format(network_interface_id))

        print("Getting EC2 client")
        ec2 = boto3.client("ec2")

        print("Getting task's network interface")
        network_interface_response = ec2.describe_network_interfaces(
            NetworkInterfaceIds=[network_interface_id]
        )
        public_ip = network_interface_response["NetworkInterfaces"][0]["Association"][
            "PublicIp"
        ]
        print("Got public IP: {}".format(public_ip))

        print("Getting Route53 client")
        route53 = boto3.client("route53")

        print("Updating DNS record")
        route53.change_resource_record_sets(
            HostedZoneId=HOSTED_ZONE_ID,
            ChangeBatch={
                "Changes": [
                    {
                        "Action": "UPSERT",
                        "ResourceRecordSet": {
                            "Name": DOMAIN,
                            "Type": "A",
                            "TTL": 300,
                            "ResourceRecords": [{"Value": public_ip}],
                        },
                    }
                ]
            },
        )
        print("Done")
