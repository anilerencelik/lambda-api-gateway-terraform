data "archive_file" "lambda-zip" {
  type        = "zip"
  source_dir  = "lambda"
  output_path = "lambda.zip"
}

resource "aws_iam_role" "lambda-iam" {
  name               = "${var.env-name}-${var.lambda-iam-name}"
  assume_role_policy = <<-POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  POLICY
}

resource "aws_lambda_function" "lambda" {
  filename         = "lambda.zip"
  function_name    = "${var.env-name}-${var.lambda-function-name}"
  role             = aws_iam_role.lambda-iam.arn
  handler          = var.lambda-function-handler
  source_code_hash = data.archive_file.lambda-zip.output_base64sha256
  runtime          = var.lambda-function-runtime
  memory_size      = var.lambda-function-memory-size
  timeout          = var.lambda-function-timeout

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.cw-log-group,
  ]
}

resource "aws_apigatewayv2_api" "lambda-api" {
  name          = "${var.env-name}-${var.apigateway-api-name}"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["*"]
    allow_headers = ["*"]
  }
}

resource "aws_apigatewayv2_stage" "lambda-stage" {
  api_id      = aws_apigatewayv2_api.lambda-api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda-integration" {
  api_id                 = aws_apigatewayv2_api.lambda-api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.lambda.invoke_arn
  passthrough_behavior   = "WHEN_NO_MATCH"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.lambda-api.id
  route_key = "${var.apigateway-route-key-method} /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda-integration.id}"
}

resource "aws_lambda_permission" "api-gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda-api.execution_arn}/*/*/{proxy+}"

}

resource "aws_cloudwatch_log_group" "cw-log-group" {
  name              = "/aws/lambda/${var.env-name}-${var.lambda-function-name}"
  retention_in_days = 14
}

# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "lambda_logging" {
  name        = "${var.env-name}-lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda-iam.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_apigatewayv2_api_mapping" "example" {
  api_id          = aws_apigatewayv2_api.lambda-api.id
  domain_name     = var.apigateway-domain-name
  stage           = aws_apigatewayv2_stage.lambda-stage.id
  api_mapping_key = var.api-domain-name-prefix-path
}
