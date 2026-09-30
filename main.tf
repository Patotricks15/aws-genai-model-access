# ─── IAM role for the model-access Lambda ────────────────────────────────────

resource "aws_iam_role" "lambda_exec" {
  name = "${local.name_prefix}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_bedrock" {
  name = "${local.name_prefix}-lambda-bedrock"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
      ]
      Resource = [
        "arn:aws:bedrock:${var.region}::foundation-model/${var.bedrock_text_model_id}",
        "arn:aws:bedrock:${var.region}::foundation-model/${var.bedrock_image_model_id}",
      ]
    }]
  })
}

# ─── Lambda package (single function that fronts every model) ───────────────

resource "null_resource" "lambda_package" {
  triggers = {
    handler_sha = filesha256("${path.module}/src/lambda/access_models/handler.py")
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/build_lambda_package.sh ${path.module} access_models"
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/lambda/access_models/handler.py"
  output_path = "${path.module}/.build/access_models.zip"

  depends_on = [null_resource.lambda_package]
}

# ─── Lambda function ──────────────────────────────────────────────────────────

resource "aws_lambda_function" "access_models" {
  function_name = "${local.name_prefix}-access-models"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      REGION         = var.region
      TEXT_MODEL_ID  = var.bedrock_text_model_id
      IMAGE_MODEL_ID = var.bedrock_image_model_id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-access-models"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_bedrock,
  ]
}

# ─── Cognito User Pool (authentication) ──────────────────────────────────────

resource "aws_cognito_user_pool" "main" {
  name = "${local.name_prefix}-${var.cognito_user_pool_name}"

  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }

  tags = local.common_tags
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "${local.name_prefix}-web-client"
  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

# ─── API Gateway REST API ─────────────────────────────────────────────────────

resource "aws_api_gateway_rest_api" "genai" {
  name        = "${local.name_prefix}-${var.api_name}"
  description = "REST API that lets devices call generative AI foundation models through a single Lambda gateway."

  tags = local.common_tags
}

# /generate resource
resource "aws_api_gateway_resource" "generate" {
  rest_api_id = aws_api_gateway_rest_api.genai.id
  parent_id   = aws_api_gateway_rest_api.genai.root_resource_id
  path_part   = "generate"
}

# Cognito authorizer
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "${local.name_prefix}-cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.genai.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.main.arn]
}

# POST /generate  →  access_models
resource "aws_api_gateway_method" "post_generate" {
  rest_api_id   = aws_api_gateway_rest_api.genai.id
  resource_id   = aws_api_gateway_resource.generate.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "post_generate" {
  rest_api_id             = aws_api_gateway_rest_api.genai.id
  resource_id             = aws_api_gateway_resource.generate.id
  http_method             = aws_api_gateway_method.post_generate.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.access_models.invoke_arn
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke-access-models"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.access_models.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.genai.execution_arn}/*/*"
}

# ─── API Gateway Deployment ───────────────────────────────────────────────────

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.genai.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.post_generate,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.post_generate,
  ]
}

resource "aws_api_gateway_stage" "v1" {
  rest_api_id   = aws_api_gateway_rest_api.genai.id
  deployment_id = aws_api_gateway_deployment.main.id
  stage_name    = var.api_stage_name

  tags = local.common_tags
}
