# SNS Topic for notifications
resource "aws_sns_topic" "drift_notifications" {
  name = "${var.cluster_name}-drift-notifications"
  tags = {
    Name = "${var.cluster_name}-drift-notifications"
  }
}

# (Optional) SNS Topic Subscription - e.g., email
# resource "aws_sns_topic_subscription" "drift_email_target" {
#   topic_arn = aws_sns_topic.drift_notifications.arn
#   protocol  = "email"
#   endpoint  = "your-email@example.com" # Replace with your email
# }
