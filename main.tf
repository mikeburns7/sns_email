# AWS SES Email Template using Terraform

# Configure AWS provider
provider "aws" {
  region = "us-east-1" # Change to your desired region
}

# Create SES Email Template
resource "aws_ses_template" "email_template" {
  name    = "my_email_template"
  subject = "{{subject}}"
  html    = <<EOF
<!DOCTYPE html>
<html>
  <body>
    <h1>{{title}}</h1>
    <p>{{message}}</p>
    <p>Event details:</p>
    <ul>
      <li>Event ID: {{event_id}}</li>
      <li>Timestamp: {{timestamp}}</li>
      <li>Details: {{details}}</li>
    </ul>
  </body>
</html>
EOF
  text    = <<EOF
{{title}}

{{message}}

Event details:
- Event ID: {{event_id}}
- Timestamp: {{timestamp}}
- Details: {{details}}
EOF
}

# Create IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "email_sender_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach SES permissions to Lambda role
resource "aws_iam_role_policy" "lambda_ses_policy" {
  name = "lambda_ses_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendTemplatedEmail",
          "ses:SendEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

# Create Lambda function
resource "aws_lambda_function" "email_sender" {
  filename      = "lambda_function.zip"  # You'll need to create this zip file with the Lambda code
  function_name = "email_sender"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"

  environment {
    variables = {
      TEMPLATE_NAME = aws_ses_template.email_template.name
      FROM_EMAIL    = "your-verified-email@domain.com"  # Replace with your SES verified email
    }
  }
}

# Create API Gateway
resource "aws_api_gateway_rest_api" "email_api" {
  name = "email-sender-api"
}

resource "aws_api_gateway_resource" "email" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  parent_id   = aws_api_gateway_rest_api.email_api.root_resource_id
  path_part   = "send-email"
}

resource "aws_api_gateway_method" "email_post" {
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  resource_id   = aws_api_gateway_resource.email.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  resource_id = aws_api_gateway_resource.email.id
  http_method = aws_api_gateway_method.email_post.http_method
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.email_sender.invoke_arn
  integration_http_method = "POST"
}

# Deploy API Gateway
resource "aws_api_gateway_deployment" "email_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  depends_on  = [aws_api_gateway_integration.lambda_integration]
}

resource "aws_api_gateway_stage" "email_api_stage" {
  deployment_id = aws_api_gateway_deployment.email_api_deployment.id
  rest_api_id  = aws_api_gateway_rest_api.email_api.id
  stage_name   = "prod"
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_sender.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.email_api.execution_arn}/*/*"
}

# Output the API endpoint URL
output "api_endpoint" {
  value = "${aws_api_gateway_stage.email_api_stage.invoke_url}/send-email"
}
