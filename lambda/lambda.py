import json

def lambda_handler(event, context):
    message = 'Hello from Lambda3!'
    return {'body': message}