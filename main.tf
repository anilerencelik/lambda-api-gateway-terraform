provider "aws" {
  region = "us-east-2"
}

module "lambda-apigateway" {
  source                      = "./lambda-apigateway"
  env-name                    = "prod-bcfm"
  apigateway-api-name         = "terraform-test-api"
  apigateway-route-key-method = "ANY"
  lambda-function-name        = "terraform-function-lambda"
  lambda-function-handler     = "lambda.lambda_handler"
  lambda-function-runtime     = "python3.8"
  lambda-function-memory-size = 512
  lambda-function-timeout     = 15
  lambda-iam-name             = "lambda-iam"
  apigateway-domain-name      = "api-ohio.kidly.world"
  api-domain-name-prefix-path = "test"
}
