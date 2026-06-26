declare module "*.json" {
  const value: {
    lexicon: number;
    id: string;
    revision?: number;
    description?: string;
    metadata?: {
      atelierStorage?: "private-kv" | "future-atproto-permissioned-data" | "public-atproto";
      privacy?: string;
    };
    defs: Record<string, unknown>;
  };
  export default value;
}
