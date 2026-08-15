// Mutating interceptor variant.
// Demonstrates:
//   - REQUEST hook: rewrite or block specific input values before they reach the tool Lambda
//   - RESPONSE hook: enrich or transform the tool result before it returns to the caller
//
// Switch to this handler by changing the Lambda `handler` in lambda-interceptor.tf:
//   handler = "index2.handler"

export const handler = async (event) => {
  console.log("incoming event", JSON.stringify(event, null, 2));

  let response;

  if (event.mcp.gatewayResponse) {
    console.log("> gateway response intercepted");
    response = {
      interceptorOutputVersion: "1.0",
      mcp: {
        transformedGatewayResponse: {
          statusCode: event.mcp.gatewayResponse.statusCode,
          body: event.mcp.gatewayResponse.body,
        },
      },
    };

    // EDIT: enrich the tool response here.
    // Example: add a metadata field to every tool-write result.
    try {
      const content = event.mcp.gatewayResponse.body?.result?.content;
      if (content && content[0]?.type === "text") {
        const parsed = JSON.parse(content[0].text);
        if (parsed.id !== undefined) {
          parsed.processedBy = "interceptor";
          response.mcp.transformedGatewayResponse.body.result.content[0].text =
            JSON.stringify(parsed);
          console.log("added processedBy field to response");
        }
      }
    } catch (e) {
      console.log("response mutation skipped:", e.message);
    }

  } else if (event.mcp.gatewayRequest) {
    console.log("> gateway request intercepted");
    response = {
      interceptorOutputVersion: "1.0",
      mcp: {
        transformedGatewayRequest: {
          body: event.mcp.gatewayRequest.body,
        },
      },
    };

    // EDIT: rewrite or validate request arguments here.
    // Example: block a specific input value.
    const args = event.mcp.gatewayRequest.body?.params?.arguments;
    if (args?.input === "blocked_value") {
      console.log("blocking request with input=blocked_value");
      response.mcp.transformedGatewayRequest.body.params.arguments.input = "default_value";
    }
  }

  console.log("interceptor response", JSON.stringify(response, null, 2));
  return response;
};
