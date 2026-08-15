// =============================================================================
// EDIT: implement your write operation here.
// Requires gateway/write scope (enforced by Cedar policy in gateway-policies.tf).
// The event object contains whatever fields you declared in tool_schema (gateway.tf).
// Return a plain JSON-serialisable object.
// =============================================================================

export const handler = async (event) => {
  console.log({ event });

  const { input } = event;
  if (!input) {
    return { error: "input is required" };
  }

  return {
    id: crypto.randomUUID(),
    input,
    status: "created",
  };
};
