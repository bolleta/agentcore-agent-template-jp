// =============================================================================
// EDIT: implement your read-only lookup here.
// The event object contains whatever fields you declared in tool_schema (gateway.tf).
// Return a plain JSON-serialisable object.
// =============================================================================

const ITEMS = [
  { id: 1, name: "Item A", description: "First item" },
  { id: 2, name: "Item B", description: "Second item" },
  { id: 3, name: "Item C", description: "Third item" },
];

export const handler = async (event) => {
  console.log({ event });
  return { items: ITEMS };
};
