import boto3


DOMAIN = "bills.elliotmarsden.com"
HOSTED_ZONE_ID = "Z04120032SGETY36T482H"

def lambda_handler(event, context):
    if event["detail"]["lastStatus"] == "RUNNING":
        print('Getting task ARN from event')
        containers = event["detail"]["containers"]
        assert len(containers) == 1
        container = containers[0]
        task_arn = container["taskArn"]

        print("Getting ECS client")
        ecs = boto3.client("ecs")
        print("Getting task network interface ID")
        response = ecs.describe_tasks(
            cluster=event["detail"]["clusterArn"], tasks=[task_arn]
        )
        task = response["tasks"][0]
        network_interface_id = task["attachments"][0]["details"][0]["value"]

        print("Getting EC2 client")
        ec2 = boto3.client("ec2")
        print("Getting task network interface")
        network_interface = ec2.describe_network_interfaces(
            NetworkInterfaceIds=[network_interface_id]
        )
        public_ip = network_interface["NetworkInterfaces"][0]["Association"]["PublicIp"]
        print(public_ip)

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
