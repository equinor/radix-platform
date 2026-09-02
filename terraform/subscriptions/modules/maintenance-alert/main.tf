################################################################################
# Reminder date calculation
#
# The Nth-weekday-of-month maintenance schedule isn't exposed as an Azure event,
# so the reminder day is computed in KQL and evaluated once a day.
################################################################################

locals {
  day_of_week_map = {
    Sunday    = 0
    Monday    = 1
    Tuesday   = 2
    Wednesday = 3
    Thursday  = 4
    Friday    = 5
    Saturday  = 6
  }
  week_index_map = {
    First  = 1
    Second = 2
    Third  = 3
    Fourth = 4
  }

  alert_query = <<-KQL
    let scheduleDow = ${local.day_of_week_map[var.day_of_week]};
    let weekIndex = ${local.week_index_map[var.week_index]};
    let daysBefore = ${var.days_before};
    let today = startofday(now());
    let monthStart = startofmonth(today);
    let firstDowOffset = (scheduleDow - toint(dayofweek(monthStart) / 1d) + 7) % 7;
    let firstTarget = monthStart + firstDowOffset * 1d;
    let targetDate = firstTarget + (weekIndex - 1) * 7d;
    let alertDate = targetDate - daysBefore * 1d;
    print IsAlertDay = iif(today == alertDate, 1, 0)
    | where IsAlertDay == 1
  KQL
}

################################################################################
# Slack notification (Logic App), following the same Slack-webhook pattern as
# the key-vault module
################################################################################

data "azurerm_key_vault" "config" {
  name                = var.key_vault_name
  resource_group_name = var.key_vault_resource_group
}

data "azurerm_key_vault_secret" "slack_webhook" {
  count        = var.enabled ? 1 : 0
  name         = "slack-webhook"
  key_vault_id = data.azurerm_key_vault.config.id
}

resource "azurerm_logic_app_workflow" "this" {
  count               = var.enabled ? 1 : 0
  name                = "${var.cluster_name}-maintenance-alert"
  location            = var.location
  resource_group_name = var.resource_group_name

  workflow_parameters = {
    SlackWebhookUrl = jsonencode({
      defaultValue = nonsensitive(data.azurerm_key_vault_secret.slack_webhook[0].value)
      metadata = {
        description = "Slack webhook URL for notifications"
      }
      type = "String"
    })
  }

  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_logic_app_trigger_http_request" "this" {
  count        = var.enabled ? 1 : 0
  name         = "When_a_HTTP_request_is_received"
  logic_app_id = azurerm_logic_app_workflow.this[0].id
  schema = jsonencode({
    type       = "object"
    properties = {}
  })
}

resource "azurerm_logic_app_action_custom" "send_slack" {
  count        = var.enabled ? 1 : 0
  name         = "Send_Slack_Notification"
  logic_app_id = azurerm_logic_app_workflow.this[0].id
  body = jsonencode({
    type = "Http"
    inputs = {
      method = "POST"
      uri    = "@parameters('SlackWebhookUrl')"
      headers = {
        Content-Type = "application/json"
      }
      body = {
        text = "@{concat(':calendar: *Upcoming AKS node OS maintenance*\n*Cluster:* ${var.cluster_name}\n*Scheduled:* ', formatDateTime(addDays(coalesce(triggerBody()?['data']?['essentials']?['firedDateTime'], utcNow()), ${var.days_before}), 'dddd, dd MMMM yyyy'), ' from ${var.start_time} for ~${var.duration_hours}h (UTC${var.utc_offset})')}"
      }
    }
    runAfter = {}
  })
}

################################################################################
# Action Group: native email receiver + Logic App receiver for Slack
################################################################################

resource "azurerm_monitor_action_group" "this" {
  count               = var.enabled ? 1 : 0
  name                = "ag-${var.cluster_name}-maintenance"
  resource_group_name = var.resource_group_name
  short_name          = substr(replace("${var.cluster_name}mnt", "-", ""), 0, 12)

  email_receiver {
    name          = "radix-mail"
    email_address = var.email_address
  }

  logic_app_receiver {
    name                    = "slack-notify"
    resource_id             = azurerm_logic_app_workflow.this[0].id
    callback_url            = azurerm_logic_app_trigger_http_request.this[0].callback_url
    use_common_alert_schema = true
  }
}

################################################################################
# Scheduled Query Rule: fires once, N days before the scheduled maintenance
################################################################################

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "this" {
  count                = var.enabled ? 1 : 0
  name                 = "${var.cluster_name}-maintenance-reminder"
  resource_group_name  = var.resource_group_name
  location             = var.location
  evaluation_frequency = "P1D"
  window_duration      = "P1D"
  scopes               = [var.log_analytics_workspace_id]
  severity             = 3

  criteria {
    query                   = local.alert_query
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
  }

  action {
    action_groups = [azurerm_monitor_action_group.this[0].id]
  }

  tags = {
    IaC = "terraform"
  }
}
