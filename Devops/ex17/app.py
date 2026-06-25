import boto3

table_name = "users"

# Since boto3 is running inside EKS container using IRSA, it will automatically detect the
# AWS_ROLE_ARN and AWS_WEB_IDENTITY_TOKEN_FILE environment variables to assume the IAM Role.
ddb = boto3.resource("dynamodb", region_name="ap-south-1")
table = ddb.Table(table_name)

# PutItem
table.put_item(
    Item={
        "id": "1",
        "name": "Hari"
    }
)
print("PutItem Success")

# GetItem
response = table.get_item(
    Key={
        "id": "1"
    }
)
print(response["Item"])

# UpdateItem
table.update_item(
    Key={"id": "1"},
    UpdateExpression="SET #n = :v",
    ExpressionAttributeNames={
        "#n": "name"
    },
    ExpressionAttributeValues={
        ":v": "Hari Updated"
    }
)
print("UpdateItem Success")
