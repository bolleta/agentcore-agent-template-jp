def lambda_handler(event, context):
    """
    Example Lambda tool handler.

    Replace this with your tool's actual logic.
    The event dict contains the tool's input parameters as defined in
    terraform/gateway/gateway.tf (aws_bedrockagentcore_gateway_target tool_schema).

    Return a dict — it is serialized to JSON and returned to the agent.
    """
    tool_input = event.get("input", "")

    # TODO: replace with real logic (database lookup, API call, etc.)
    return {
        "result": f"Example tool received: {tool_input}",
        "status": "ok",
    }
