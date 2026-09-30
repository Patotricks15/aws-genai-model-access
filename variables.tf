variable "project_name" {
  description = "Project name used as prefix for all resources."
  type        = string
  default     = "floci-genai"
}

variable "region" {
  description = "AWS region (simulated by floci)."
  type        = string
  default     = "us-east-1"
}

variable "cognito_user_pool_name" {
  description = "Name of the Cognito User Pool for authentication."
  type        = string
  default     = "genai-users"
}

variable "api_name" {
  description = "Name of the REST API Gateway."
  type        = string
  default     = "genai-model-access-api"
}

variable "api_stage_name" {
  description = "Deployment stage name for the API Gateway."
  type        = string
  default     = "v1"
}

variable "bedrock_text_model_id" {
  description = "Bedrock foundation model id used for text summarization and virtual assistant tasks."
  type        = string
  default     = "amazon.titan-text-express-v1"
}

variable "bedrock_image_model_id" {
  description = "Bedrock foundation model id used for image generation tasks."
  type        = string
  default     = "stability.stable-diffusion-xl-v1"
}
