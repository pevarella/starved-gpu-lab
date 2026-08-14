import os
import boto3

eks = boto3.client("eks")

def lambda_handler(event, context):
    cluster_name = os.environ["CLUSTER_NAME"]
    node_group_name = os.environ["NODE_GROUP_NAME"]

    print(
        f"Scaling node group {node_group_name} "
        f"from cluster {cluster_name} to 0"
    )

    response = eks.update_nodegroup_config(
        clusterName=cluster_name,
        nodegroupName=node_group_name,
        scalingConfig={
            "minSize": 0,
            "desireSize": 0,
        },
    )

    update_id = response["update"]["id"]

    print(f"EKS update started: {update_id}")

    return {
        "statusCode": 200,
        "cluster": cluster_name,
        "nodeGroup": node_group_name,
        "desiredSize": 0,
        "updateId": update_id,
    }