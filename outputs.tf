output "api_endpoint" {
  description = "Base URL of the Generative AI model access REST API."
  value       = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.genai.id}/${var.api_stage_name}/_user_request_"
}

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool."
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "ID of the Cognito app client."
  value       = aws_cognito_user_pool_client.web.id
}

output "lambda_function_name" {
  description = "Name of the deployed model-access Lambda function."
  value       = aws_lambda_function.access_models.function_name
}
