import json
import boto3

def lambda_handler(event, context):
    if event['detail']['lastStatus'] == 'RUNNING':
        print(event)
        containers = event['detail']
        assert len(containers) == 1
        container = containers[0]
        task_arn = container['taskArn']

        ecs = boto3.client('ecs')
        response = ecs.describe_tasks(
            cluster=event['detail']['clusterArn'],
            tasks=[task_arn]
        )
        task = response['tasks'][0]
        network_interface_id = task['attachments'][0]['details'][0]['value']
        
        ec2 = boto3.client('ec2')
        network_interface = ec2.describe_network_interfaces(
            NetworkInterfaceIds=[network_interface_id]
        )
        public_ip = network_interface['NetworkInterfaces'][0]['Association']['PublicIp']
        print(public_ip)