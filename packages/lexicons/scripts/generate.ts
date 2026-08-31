import { createHash } from "node:crypto";
import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { dirname, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

type JSONPrimitive = string | number | boolean | null;
type JSONValue = JSONPrimitive | JSONValue[] | { [key: string]: JSONValue };

type LexiconNode = {
  type?: string;
  ref?: string;
  refs?: string[];
  record?: LexiconNode;
  required?: string[];
  properties?: Record<string, LexiconNode>;
  items?: LexiconNode;
  format?: string;
  default?: JSONPrimitive;
  knownValues?: string[];
  minimum?: number;
  key?: string;
  description?: string;
  permissions?: PermissionGrant[];
  [key: string]: unknown;
};

type LexiconSchema = {
  lexicon: number;
  id: string;
  defs: Record<string, LexiconNode>;
};

type PermissionGrant = {
  type: string;
  resource: string;
  collection?: string[];
  action?: string[];
};

type VendorEntry = {
  id: string;
  path: string;
  sourceUrl: string;
  sourceVersion: string;
  sourceSha256: string;
  vendoredSha256: string;
  normalization: string;
  license: string;
};

type VendorManifest = {
  version: number;
  retrievedAt: string;
  allowedUnvendoredRefs: string[];
  schemas: VendorEntry[];
};

type LoadedSchema = {
  schema: LexiconSchema;
  absolutePath: string;
  relativePath: string;
  vendored: boolean;
};

type Model = {
  schema: LexiconSchema;
  definitionName: string;
  definition: LexiconNode;
  object: LexiconNode | undefined;
  record: boolean;
  name: string;
};

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const lexiconRoot = resolve(scriptDirectory, "..");
const repositoryRoot = resolve(lexiconRoot, "../..");
const schemaRoot = resolve(lexiconRoot, "schemas");
const manifestPath = resolve(lexiconRoot, "vendor/manifest.json");
const checkMode = process.argv.includes("--check");

const outputPaths = {
  catalog: resolve(lexiconRoot, "src/generated/catalog.ts"),
  typescript: resolve(repositoryRoot, "packages/contracts/src/generated/lexicons.ts"),
  swiftPackage: resolve(repositoryRoot, "packages/swift/Sources/AtelierContracts/Generated/AtelierLexiconModels.swift"),
  swiftApple: resolve(repositoryRoot, "apps/apple/Packages/AtelierShared/Sources/AtelierContracts/Generated/AtelierLexiconModels.swift"),
  kotlin: resolve(repositoryRoot, "apps/android/contracts/src/main/kotlin/diy/atelier/contracts/generated/AtelierLexiconModels.kt"),
  compatibility: resolve(lexiconRoot, "fixtures/generated/compatibility.json"),
} as const;

function sha256(value: string | Uint8Array): string {
  return createHash("sha256").update(value).digest("hex");
}

function sortJSON(value: JSONValue): JSONValue {
  if (Array.isArray(value)) {
    return value.map(sortJSON);
  }
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, child]) => [key, sortJSON(child)]),
    );
  }
  return value;
}

function stableJSON(value: unknown, indentation?: number): string {
  return JSON.stringify(sortJSON(value as JSONValue), null, indentation);
}

function posixPath(path: string): string {
  return path.split(sep).join("/");
}

async function findJSONFiles(directory: string): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(entries.map(async (entry) => {
    const path = resolve(directory, entry.name);
    if (entry.isDirectory()) {
      return findJSONFiles(path);
    }
    return entry.isFile() && entry.name.endsWith(".json") ? [path] : [];
  }));
  return nested.flat().sort();
}

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

function isObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function validateSchemaShape(value: unknown, source: string): asserts value is LexiconSchema {
  assert(isObject(value), `${source}: schema must be an object`);
  assert(value.lexicon === 1, `${source}: only Lexicon version 1 is supported`);
  assert(typeof value.id === "string" && value.id.length > 0, `${source}: id is required`);
  assert(isObject(value.defs) && isObject(value.defs.main), `${source}: defs.main is required`);
  assert(typeof (value.defs.main as LexiconNode).type === "string", `${source}: defs.main.type is required`);
}

function splitRef(ref: string): { id: string; definitionName: string } {
  const separator = ref.indexOf("#");
  return separator === -1
    ? { id: ref, definitionName: "main" }
    : { id: ref.slice(0, separator), definitionName: ref.slice(separator + 1) || "main" };
}

function validateReferences(
  loaded: LoadedSchema[],
  allowedUnvendoredRefs: ReadonlySet<string>,
): void {
  const byID = new Map(loaded.map(({ schema }) => [schema.id, schema]));

  const validateRef = (owner: LexiconSchema, ref: string): void => {
    if (ref.startsWith("#")) {
      const definitionName = ref.slice(1);
      assert(owner.defs[definitionName], `${owner.id}: unresolved local ref ${ref}`);
      return;
    }

    const { id, definitionName } = splitRef(ref);
    const target = byID.get(id);
    if (target) {
      assert(target.defs[definitionName], `${owner.id}: unresolved ref ${ref}`);
      return;
    }
    assert(allowedUnvendoredRefs.has(ref) || allowedUnvendoredRefs.has(id), `${owner.id}: unresolved external ref ${ref}`);
  };

  const visit = (owner: LexiconSchema, value: unknown): void => {
    if (Array.isArray(value)) {
      value.forEach((child) => visit(owner, child));
      return;
    }
    if (!isObject(value)) {
      return;
    }
    if (typeof value.ref === "string") {
      validateRef(owner, value.ref);
    }
    if (Array.isArray(value.refs)) {
      value.refs.forEach((ref) => {
        assert(typeof ref === "string", `${owner.id}: union refs must be strings`);
        validateRef(owner, ref);
      });
    }
    Object.values(value).forEach((child) => visit(owner, child));
  };

  for (const { schema } of loaded) {
    visit(schema, schema.defs);
    const main = schema.defs.main;
    if (main.type === "permission-set") {
      for (const permission of main.permissions ?? []) {
        for (const collection of permission.collection ?? []) {
          const target = byID.get(collection);
          assert(target?.defs.main.type === "record", `${schema.id}: permission collection ${collection} is not a vendored record`);
        }
      }
    }
  }
}

function words(value: string): string[] {
  return value
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .split(/[^A-Za-z0-9]+/)
    .filter(Boolean);
}

function pascal(value: string): string {
  return words(value).map((word) => word[0]!.toUpperCase() + word.slice(1)).join("");
}

function modelName(schemaID: string, definitionName: string, definition: LexiconNode): string {
  const base = pascal(schemaID);
  if (definitionName === "main") {
    return definition.type === "record" ? `${base}Record` : base;
  }
  return `${base}${pascal(definitionName)}`;
}

function collectModels(loaded: LoadedSchema[]): Model[] {
  const models: Model[] = [];
  for (const { schema } of loaded) {
    for (const definitionName of Object.keys(schema.defs).sort((left, right) => {
      if (left === "main") return -1;
      if (right === "main") return 1;
      return left.localeCompare(right);
    })) {
      const definition = schema.defs[definitionName]!;
      const record = definition.type === "record";
      const object = record ? definition.record : definition.type === "object" ? definition : undefined;
      if (!object && definition.type !== "string") {
        continue;
      }
      models.push({
        schema,
        definitionName,
        definition,
        object,
        record,
        name: modelName(schema.id, definitionName, definition),
      });
    }
  }
  return models;
}

function resolveRef(
  owner: LexiconSchema,
  ref: string,
  byID: ReadonlyMap<string, LexiconSchema>,
): { schema: LexiconSchema; definitionName: string; definition: LexiconNode } | undefined {
  if (ref === "com.atproto.repo.strongRef") {
    return undefined;
  }
  const target = ref.startsWith("#")
    ? { id: owner.id, definitionName: ref.slice(1) }
    : splitRef(ref);
  const schema = byID.get(target.id);
  if (!schema) {
    return undefined;
  }
  const definition = schema.defs[target.definitionName];
  assert(definition, `${owner.id}: missing already-validated ref ${ref}`);
  return { schema, definitionName: target.definitionName, definition };
}

function typescriptType(owner: LexiconSchema, node: LexiconNode, byID: ReadonlyMap<string, LexiconSchema>): string {
  switch (node.type) {
    case "string": return "string";
    case "integer": return "number";
    case "boolean": return "boolean";
    case "blob": return "AtelierBlobReference";
    case "array": return `ReadonlyArray<${typescriptType(owner, node.items ?? {}, byID)}>`;
    case "union": return "AtelierLexiconJSONValue";
    case "ref": {
      assert(node.ref, `${owner.id}: ref node is missing ref`);
      if (node.ref === "com.atproto.repo.strongRef") return "AtelierStrongRef";
      const target = resolveRef(owner, node.ref, byID);
      return target ? modelName(target.schema.id, target.definitionName, target.definition) : "AtelierLexiconJSONValue";
    }
    default: return "AtelierLexiconJSONValue";
  }
}

function swiftType(owner: LexiconSchema, node: LexiconNode, byID: ReadonlyMap<string, LexiconSchema>): string {
  switch (node.type) {
    case "string": return "String";
    case "integer": return "Int64";
    case "boolean": return "Bool";
    case "blob": return "AtelierBlobReference";
    case "array": return `[${swiftType(owner, node.items ?? {}, byID)}]`;
    case "union": return "AtelierLexiconJSONValue";
    case "ref": {
      assert(node.ref, `${owner.id}: ref node is missing ref`);
      if (node.ref === "com.atproto.repo.strongRef") return "AtelierStrongRef";
      const target = resolveRef(owner, node.ref, byID);
      return target ? modelName(target.schema.id, target.definitionName, target.definition) : "AtelierLexiconJSONValue";
    }
    default: return "AtelierLexiconJSONValue";
  }
}

function kotlinType(owner: LexiconSchema, node: LexiconNode, byID: ReadonlyMap<string, LexiconSchema>): string {
  switch (node.type) {
    case "string": return "String";
    case "integer": return "Long";
    case "boolean": return "Boolean";
    case "blob": return "AtelierBlobReference";
    case "array": return `List<${kotlinType(owner, node.items ?? {}, byID)}>`;
    case "union": return "Any?";
    case "ref": {
      assert(node.ref, `${owner.id}: ref node is missing ref`);
      if (node.ref === "com.atproto.repo.strongRef") return "AtelierStrongRef";
      const target = resolveRef(owner, node.ref, byID);
      return target ? modelName(target.schema.id, target.definitionName, target.definition) : "Any?";
    }
    default: return "Any?";
  }
}

const fixedDate = "2026-01-02T03:04:05.000Z";

function sampleString(propertyName: string, node: LexiconNode): string {
  if (typeof node.default === "string") return node.default;
  if (node.knownValues?.length) return node.knownValues[0]!;
  if (node.format === "datetime") return fixedDate;
  if (node.format === "did") return "did:plc:ateliercompatibility";
  if (node.format === "uri") return "https://atelier.diy/compatibility";
  const values: Record<string, string> = {
    title: "Compatibility title",
    name: "Compatibility name",
    uid: "compatibility-event@atelier.diy",
    icalendar: "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nEND:VCALENDAR\r\n",
    markdown: "# Compatibility\n",
    service: "atelier",
    mode: "foundation",
    publicPdsDisclosure: "Standard AT Protocol repository records are publicly readable.",
    provider: "gmail",
    opaqueId: "hmac-sha256:compatibility",
    resourceKind: "thread",
    sourceVersion: "compatibility-v1",
    contentHash: "sha256:compatibility",
    persistenceState: "durable",
    state: "inbox",
    status: "todo",
    kind: "relatesTo",
    availability: "contractOnly",
  };
  return values[propertyName] ?? `compatibility-${propertyName}`;
}

function sampleValue(
  owner: LexiconSchema,
  propertyName: string,
  node: LexiconNode,
  byID: ReadonlyMap<string, LexiconSchema>,
  stack: ReadonlySet<string>,
): JSONValue {
  switch (node.type) {
    case "string": return sampleString(propertyName, node);
    case "integer": return typeof node.minimum === "number" ? node.minimum : 1;
    case "boolean": return true;
    case "blob": return {
      "$type": "blob",
      ref: { "$link": "bafyreiaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
      mimeType: "application/octet-stream",
      size: 1,
    };
    case "array": return [sampleValue(owner, propertyName, node.items ?? {}, byID, stack)];
    case "union": return {};
    case "ref": {
      assert(node.ref, `${owner.id}: ref node is missing ref`);
      if (node.ref === "com.atproto.repo.strongRef") {
        return {
          uri: "at://did:plc:ateliercompatibility/diy.atelier.project.project/compatibility",
          cid: { "$link": "bafyreiaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        };
      }
      const target = resolveRef(owner, node.ref, byID);
      if (!target) return {};
      if (target.definition.type === "string") return sampleString(propertyName, target.definition);
      const object = target.definition.type === "record" ? target.definition.record : target.definition;
      return sampleObject(target.schema, object ?? {}, byID, stack, false);
    }
    default: return {};
  }
}

function sampleObject(
  owner: LexiconSchema,
  object: LexiconNode,
  byID: ReadonlyMap<string, LexiconSchema>,
  stack: ReadonlySet<string>,
  includeType: boolean,
): { [key: string]: JSONValue } {
  assert(!stack.has(owner.id), `${owner.id}: recursive required object cannot produce a finite compatibility sample`);
  const nextStack = new Set(stack).add(owner.id);
  const sample: { [key: string]: JSONValue } = {};
  if (includeType) sample.$type = owner.id;
  for (const propertyName of object.required ?? []) {
    const property = object.properties?.[propertyName];
    assert(property, `${owner.id}: required property ${propertyName} is not declared`);
    sample[propertyName] = sampleValue(owner, propertyName, property, byID, nextStack);
  }
  return sample;
}

function tsString(value: string): string {
  return JSON.stringify(value);
}

function swiftString(value: string): string {
  return JSON.stringify(value);
}

function kotlinString(value: string): string {
  return JSON.stringify(value).replace(/\$/g, "\\$");
}

const swiftKeywords = new Set([
  "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init",
  "inout", "internal", "let", "open", "operator", "private", "precedencegroup", "protocol", "public",
  "rethrows", "static", "struct", "subscript", "typealias", "var", "break", "case", "continue", "default",
  "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch", "where",
  "while", "as", "catch", "false", "is", "nil", "super", "self", "Self", "throw", "throws", "true", "try",
]);

function swiftIdentifier(value: string): string {
  return swiftKeywords.has(value) ? `\`${value}\`` : value;
}

const kotlinKeywords = new Set([
  "as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if", "in", "interface", "is",
  "null", "object", "package", "return", "super", "this", "throw", "true", "try", "typealias", "typeof", "val",
  "var", "when", "while",
]);

function kotlinIdentifier(value: string): string {
  return kotlinKeywords.has(value) ? `\`${value}\`` : value;
}

function generateCatalog(loaded: LoadedSchema[]): string {
  const imports = loaded.map(({ relativePath }, index) =>
    `import schema${String(index).padStart(2, "0")} from ${tsString(`../../schemas/${relativePath}`)};`,
  ).join("\n");
  const identifiers = loaded.map((_, index) => `  schema${String(index).padStart(2, "0")},`).join("\n");
  return `// Generated by packages/lexicons/scripts/generate.ts. Do not edit.\n${imports}\n\n` +
    `export type AtelierLexiconSchema = {\n  readonly id: string;\n  readonly defs: Record<string, { readonly type?: string; readonly [key: string]: unknown }>;\n};\n\n` +
    `export const atelierLexicons = [\n${identifiers}\n] as readonly AtelierLexiconSchema[];\n\n` +
    `export const atelierLexiconByNSID = new Map(atelierLexicons.map((schema) => [schema.id, schema]));\n\n` +
    `export type AtelierRecordLexicon = AtelierLexiconSchema & {\n  readonly defs: { readonly main: { readonly type: "record"; readonly record: { readonly properties?: Record<string, unknown> } } };\n};\n\n` +
    `export function isAtelierRecordLexicon(schema: AtelierLexiconSchema): schema is AtelierRecordLexicon {\n  return schema.defs.main?.type === "record" && "record" in schema.defs.main;\n}\n\n` +
    `export const atelierCollectionNSIDs = atelierLexicons.filter(isAtelierRecordLexicon).map((schema) => schema.id);\n`;
}

function generateTypeScript(
  models: Model[],
  byID: ReadonlyMap<string, LexiconSchema>,
  records: Array<{ schema: LexiconSchema; vendored: boolean; sample: Record<string, JSONValue>; canonical: string; digest: string }>,
  permissionSets: Record<string, PermissionGrant[]>,
  schemaDigest: string,
  compatibilityDigest: string,
  manifest: VendorManifest,
): string {
  const declarations = models.map((model) => {
    if (!model.object) {
      return `export type ${model.name} = string;`;
    }
    const required = new Set(model.object.required ?? []);
    const properties = Object.entries(model.object.properties ?? {}).map(([propertyName, property]) =>
      `  readonly ${tsString(propertyName)}${required.has(propertyName) ? "" : "?"}: ${typescriptType(model.schema, property, byID)};`,
    );
    if (model.record) {
      properties.unshift(`  readonly "$type"?: ${tsString(model.schema.id)};`);
    }
    return `export interface ${model.name} {\n${properties.join("\n")}\n}`;
  }).join("\n\n");

  const recordMetadata = Object.fromEntries(records.map(({ schema, vendored }) => [schema.id, {
    nsid: schema.id,
    key: schema.defs.main.key ?? null,
    requiredFields: schema.defs.main.record?.required ?? [],
    publicData: true,
    source: vendored ? "vendored" : "first-party",
  }]));
  const samples = Object.fromEntries(records.map(({ schema, canonical }) => [schema.id, canonical]));
  const vendorDigests = Object.fromEntries(manifest.schemas.map((entry) => [entry.id, entry.vendoredSha256]));
  const collections = records.map(({ schema }) => schema.id);

  return `// Generated by packages/lexicons/scripts/generate.ts. Do not edit.\n` +
    `export type AtelierLexiconJSONValue = null | boolean | number | string | ReadonlyArray<AtelierLexiconJSONValue> | { readonly [key: string]: AtelierLexiconJSONValue };\n\n` +
    `export interface AtelierCIDLink { readonly "$link": string; }\n` +
    `export interface AtelierStrongRef { readonly uri: string; readonly cid: AtelierCIDLink; }\n` +
    `export interface AtelierBlobReference { readonly "$type": "blob"; readonly ref: AtelierCIDLink; readonly mimeType: string; readonly size: number; }\n\n` +
    `${declarations}\n\n` +
    `export interface AtelierRecordMetadata { readonly nsid: string; readonly key: string | null; readonly requiredFields: readonly string[]; readonly publicData: true; readonly source: "first-party" | "vendored"; }\n` +
    `export interface AtelierPermissionGrant { readonly type: string; readonly resource: string; readonly collection?: readonly string[]; readonly action?: readonly string[]; }\n\n` +
    `export const atelierRecordMetadata = ${JSON.stringify(recordMetadata, null, 2)} as const satisfies Record<string, AtelierRecordMetadata>;\n\n` +
    `export type AtelierRecordNSID = keyof typeof atelierRecordMetadata;\n\n` +
    `export const atelierCollectionNSIDs = ${JSON.stringify(collections, null, 2)} as const;\n\n` +
    `export const atelierPermissionSets = ${JSON.stringify(permissionSets, null, 2)} as const satisfies Record<string, readonly AtelierPermissionGrant[]>;\n\n` +
    `export type AtelierPermissionSetNSID = keyof typeof atelierPermissionSets;\n\n` +
    `export const atelierCanonicalRecordJSON = ${JSON.stringify(samples, null, 2)} as const;\n\n` +
    `export const atelierVendoredSchemaDigests = ${JSON.stringify(vendorDigests, null, 2)} as const;\n\n` +
    `export const atelierLexiconDigest = ${tsString(schemaDigest)};\n` +
    `export const atelierCompatibilityDigest = ${tsString(compatibilityDigest)};\n`;
}

function generateSwift(
  models: Model[],
  byID: ReadonlyMap<string, LexiconSchema>,
  records: Array<{ schema: LexiconSchema; vendored: boolean; canonical: string }>,
  permissionSets: Record<string, PermissionGrant[]>,
  schemaDigest: string,
  compatibilityDigest: string,
  manifest: VendorManifest,
): string {
  const declarations = models.map((model) => {
    if (!model.object) return `public typealias ${model.name} = String`;
    const required = new Set(model.object.required ?? []);
    const entries = Object.entries(model.object.properties ?? {});
    const fields: string[] = [];
    if (model.record) {
      fields.push(`    public static let nsid = ${swiftString(model.schema.id)}`);
      fields.push(`    public static let requiredFields = ${JSON.stringify(model.object.required ?? [])}`);
      fields.push("    public static let isPublicPDSData = true");
      fields.push("");
      fields.push("    public let recordType: String?");
    }
    for (const [propertyName, property] of entries) {
      const optional = required.has(propertyName) ? "" : "?";
      fields.push(`    public let ${swiftIdentifier(propertyName)}: ${swiftType(model.schema, property, byID)}${optional}`);
    }

    const orderedParameters = [
      ...entries.filter(([name]) => required.has(name)),
      ...entries.filter(([name]) => !required.has(name)),
    ];
    const parameters = orderedParameters.map(([propertyName, property]) => {
      const optional = !required.has(propertyName);
      return `${swiftIdentifier(propertyName)}: ${swiftType(model.schema, property, byID)}${optional ? "? = nil" : ""}`;
    });
    if (model.record) parameters.push(`recordType: String? = ${swiftString(model.schema.id)}`);
    const assignments: string[] = [];
    if (model.record) assignments.push("        self.recordType = recordType");
    for (const [propertyName] of entries) {
      const identifier = swiftIdentifier(propertyName);
      assignments.push(`        self.${identifier} = ${identifier}`);
    }
    fields.push("");
    fields.push(`    public init(\n        ${parameters.join(",\n        ")}\n    ) {`);
    fields.push(assignments.join("\n"));
    fields.push("    }");
    fields.push("");
    fields.push("    private enum CodingKeys: String, CodingKey {");
    if (model.record) fields.push('        case recordType = "$type"');
    for (const [propertyName] of entries) {
      const identifier = swiftIdentifier(propertyName);
      fields.push(identifier === propertyName
        ? `        case ${identifier}`
        : `        case ${identifier} = ${swiftString(propertyName)}`);
    }
    fields.push("    }");
    return `public struct ${model.name}: Codable, Equatable, Sendable {\n${fields.join("\n")}\n}`;
  }).join("\n\n");

  const metadataEntries = records.map(({ schema, vendored }) => {
    const main = schema.defs.main;
    return `        ${swiftString(schema.id)}: .init(nsid: ${swiftString(schema.id)}, key: ${main.key ? swiftString(main.key) : "nil"}, requiredFields: ${JSON.stringify(main.record?.required ?? [])}, publicData: true, source: ${swiftString(vendored ? "vendored" : "first-party")})`;
  }).join(",\n");
  const canonicalEntries = records.map(({ schema, canonical }) =>
    `        ${swiftString(schema.id)}: ${swiftString(canonical)}`,
  ).join(",\n");
  const permissionEntries = Object.entries(permissionSets).map(([id, grants]) => {
    const swiftGrants = grants.map((grant) => `.init(resource: ${swiftString(grant.resource)}, collections: ${JSON.stringify(grant.collection ?? [])}, actions: ${JSON.stringify(grant.action ?? [])})`).join(", ");
    return `        ${swiftString(id)}: [${swiftGrants}]`;
  }).join(",\n");
  const vendorEntries = manifest.schemas.map((entry) =>
    `        ${swiftString(entry.id)}: ${swiftString(entry.vendoredSha256)}`,
  ).join(",\n");

  return `// Generated by packages/lexicons/scripts/generate.ts. Do not edit.\nimport Foundation\n\n` +
`public indirect enum AtelierLexiconJSONValue: Codable, Equatable, Sendable {
    case null
    case boolean(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([AtelierLexiconJSONValue])
    case object([String: AtelierLexiconJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .boolean(value) }
        else if let value = try? container.decode(Int64.self) { self = .integer(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([AtelierLexiconJSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: AtelierLexiconJSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .boolean(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

public struct AtelierCIDLink: Codable, Equatable, Sendable {
    public let link: String
    public init(link: String) { self.link = link }
    private enum CodingKeys: String, CodingKey { case link = "$link" }
}

public struct AtelierStrongRef: Codable, Equatable, Sendable {
    public let uri: String
    public let cid: AtelierCIDLink
    public init(uri: String, cid: AtelierCIDLink) { self.uri = uri; self.cid = cid }
}

public struct AtelierBlobReference: Codable, Equatable, Sendable {
    public let recordType: String
    public let ref: AtelierCIDLink
    public let mimeType: String
    public let size: Int64
    public init(recordType: String = "blob", ref: AtelierCIDLink, mimeType: String, size: Int64) {
        self.recordType = recordType; self.ref = ref; self.mimeType = mimeType; self.size = size
    }
    private enum CodingKeys: String, CodingKey { case recordType = "$type"; case ref, mimeType, size }
}

${declarations}

public struct AtelierGeneratedRecordMetadata: Equatable, Sendable {
    public let nsid: String
    public let key: String?
    public let requiredFields: [String]
    public let publicData: Bool
    public let source: String
    public init(nsid: String, key: String?, requiredFields: [String], publicData: Bool, source: String) {
        self.nsid = nsid; self.key = key; self.requiredFields = requiredFields; self.publicData = publicData; self.source = source
    }
}

public struct AtelierGeneratedPermissionGrant: Equatable, Sendable {
    public let resource: String
    public let collections: [String]
    public let actions: [String]
    public init(resource: String, collections: [String], actions: [String]) {
        self.resource = resource; self.collections = collections; self.actions = actions
    }
}

public enum AtelierGeneratedLexiconCatalog: Sendable {
    public static let schemaDigest = ${swiftString(schemaDigest)}
    public static let compatibilityDigest = ${swiftString(compatibilityDigest)}
    public static let recordMetadata: [String: AtelierGeneratedRecordMetadata] = [
${metadataEntries}
    ]
    public static let permissionSets: [String: [AtelierGeneratedPermissionGrant]] = [
${permissionEntries}
    ]
    public static let canonicalRecordJSON: [String: String] = [
${canonicalEntries}
    ]
    public static let vendoredSchemaDigests: [String: String] = [
${vendorEntries}
    ]
}
`;
}

function generateKotlin(
  models: Model[],
  byID: ReadonlyMap<string, LexiconSchema>,
  records: Array<{ schema: LexiconSchema; vendored: boolean; canonical: string }>,
  permissionSets: Record<string, PermissionGrant[]>,
  schemaDigest: string,
  compatibilityDigest: string,
  manifest: VendorManifest,
): string {
  const declarations = models.map((model) => {
    if (!model.object) return `typealias ${model.name} = String`;
    const required = new Set(model.object.required ?? []);
    const entries = [
      ...Object.entries(model.object.properties ?? {}).filter(([name]) => required.has(name)),
      ...Object.entries(model.object.properties ?? {}).filter(([name]) => !required.has(name)),
    ];
    const parameters = entries.map(([propertyName, property]) => {
      const optional = !required.has(propertyName);
      return `    val ${kotlinIdentifier(propertyName)}: ${kotlinType(model.schema, property, byID)}${optional ? "? = null" : ""}`;
    });
    if (model.record) parameters.push(`    val recordType: String = NSID`);
    const companion = model.record
      ? ` {\n    companion object {\n        const val NSID = ${kotlinString(model.schema.id)}\n        val REQUIRED_FIELDS = ${kotlinStringList(model.object.required ?? [])}\n        const val IS_PUBLIC_PDS_DATA = true\n    }\n}`
      : "";
    return `data class ${model.name}(\n${parameters.join(",\n")}\n)${companion}`;
  }).join("\n\n");

  const metadataEntries = records.map(({ schema, vendored }) => {
    const main = schema.defs.main;
    return `        ${kotlinString(schema.id)} to AtelierGeneratedRecordMetadata(${kotlinString(schema.id)}, ${main.key ? kotlinString(main.key) : "null"}, ${kotlinStringList(main.record?.required ?? [])}, true, ${kotlinString(vendored ? "vendored" : "first-party")})`;
  }).join(",\n");
  const canonicalEntries = records.map(({ schema, canonical }) =>
    `        ${kotlinString(schema.id)} to ${kotlinString(canonical)}`,
  ).join(",\n");
  const permissionEntries = Object.entries(permissionSets).map(([id, grants]) => {
    const kotlinGrants = grants.map((grant) => `AtelierGeneratedPermissionGrant(${kotlinString(grant.resource)}, ${kotlinStringList(grant.collection ?? [])}, ${kotlinStringList(grant.action ?? [])})`).join(", ");
    return `        ${kotlinString(id)} to listOf(${kotlinGrants})`;
  }).join(",\n");
  const vendorEntries = manifest.schemas.map((entry) =>
    `        ${kotlinString(entry.id)} to ${kotlinString(entry.vendoredSha256)}`,
  ).join(",\n");

  return `// Generated by packages/lexicons/scripts/generate.ts. Do not edit.\npackage diy.atelier.contracts.generated\n\n` +
`data class AtelierCIDLink(val link: String)

data class AtelierStrongRef(val uri: String, val cid: AtelierCIDLink)

data class AtelierBlobReference(
    val recordType: String = "blob",
    val ref: AtelierCIDLink,
    val mimeType: String,
    val size: Long,
)

${declarations}

data class AtelierGeneratedRecordMetadata(
    val nsid: String,
    val key: String?,
    val requiredFields: List<String>,
    val publicData: Boolean,
    val source: String,
)

data class AtelierGeneratedPermissionGrant(
    val resource: String,
    val collections: List<String>,
    val actions: List<String>,
)

object AtelierGeneratedLexiconCatalog {
    const val SCHEMA_DIGEST = ${kotlinString(schemaDigest)}
    const val COMPATIBILITY_DIGEST = ${kotlinString(compatibilityDigest)}
    val recordMetadata = mapOf(
${metadataEntries}
    )
    val permissionSets = mapOf(
${permissionEntries}
    )
    val canonicalRecordJson = mapOf(
${canonicalEntries}
    )
    val vendoredSchemaDigests = mapOf(
${vendorEntries}
    )
}
`;
}

function kotlinStringList(values: string[]): string {
  return values.length === 0 ? "emptyList()" : `listOf(${values.map(kotlinString).join(", ")})`;
}

async function loadInputs(): Promise<{ loaded: LoadedSchema[]; manifest: VendorManifest }> {
  const manifest = JSON.parse(await readFile(manifestPath, "utf8")) as VendorManifest;
  assert(manifest.version === 1, "vendor manifest: unsupported version");
  assert(Array.isArray(manifest.schemas), "vendor manifest: schemas must be an array");
  assert(Array.isArray(manifest.allowedUnvendoredRefs), "vendor manifest: allowedUnvendoredRefs must be an array");

  const files = await findJSONFiles(schemaRoot);
  const loaded = await Promise.all(files.map(async (absolutePath): Promise<LoadedSchema> => {
    const relativePath = posixPath(relative(schemaRoot, absolutePath));
    const parsed: unknown = JSON.parse(await readFile(absolutePath, "utf8"));
    validateSchemaShape(parsed, relativePath);
    return { schema: parsed, absolutePath, relativePath, vendored: relativePath.startsWith("vendor/") };
  }));
  loaded.sort((left, right) => left.schema.id.localeCompare(right.schema.id));
  const ids = loaded.map(({ schema }) => schema.id);
  assert(new Set(ids).size === ids.length, "schema ids must be unique");

  const manifestIDs = new Set(manifest.schemas.map((entry) => entry.id));
  const vendorSchemas = loaded.filter(({ vendored }) => vendored);
  assert(manifestIDs.size === manifest.schemas.length, "vendor manifest ids must be unique");
  assert(vendorSchemas.length === manifest.schemas.length, "every vendored schema must have exactly one manifest entry");
  for (const entry of manifest.schemas) {
    const absolutePath = resolve(lexiconRoot, entry.path);
    const matching = loaded.find((candidate) => candidate.absolutePath === absolutePath);
    assert(matching?.vendored, `vendor manifest: ${entry.path} is not a vendored schema input`);
    assert(matching.schema.id === entry.id, `vendor manifest: ${entry.path} declares ${matching.schema.id}, expected ${entry.id}`);
    const digest = sha256(await readFile(absolutePath));
    assert(digest === entry.vendoredSha256, `vendor manifest: ${entry.id} digest mismatch; expected ${entry.vendoredSha256}, received ${digest}`);
  }
  for (const { schema } of vendorSchemas) {
    assert(manifestIDs.has(schema.id), `vendor manifest: missing ${schema.id}`);
  }
  validateReferences(loaded, new Set(manifest.allowedUnvendoredRefs));
  return { loaded, manifest };
}

async function main(): Promise<void> {
  const { loaded, manifest } = await loadInputs();
  const byID = new Map(loaded.map(({ schema }) => [schema.id, schema]));
  const schemaDigest = sha256(stableJSON(loaded.map(({ schema }) => schema)));
  const models = collectModels(loaded);
  const records = loaded
    .filter(({ schema }) => schema.defs.main.type === "record")
    .map((entry) => {
      const object = entry.schema.defs.main.record;
      assert(object, `${entry.schema.id}: record definition is required`);
      const sample = sampleObject(entry.schema, object, byID, new Set(), true);
      const canonical = stableJSON(sample);
      return { ...entry, sample, canonical, digest: sha256(canonical) };
    });
  const permissionSets = Object.fromEntries(loaded
    .filter(({ schema }) => schema.defs.main.type === "permission-set")
    .map(({ schema }) => [schema.id, schema.defs.main.permissions ?? []] as const));
  const compatibilityBase = {
    formatVersion: 1,
    schemaDigest,
    records: Object.fromEntries(records.map(({ schema, sample, canonical, digest }) => [schema.id, {
      requiredFields: schema.defs.main.record?.required ?? [],
      publicData: true,
      sample,
      canonicalJSON: canonical,
      sampleSha256: digest,
    }])),
    permissionSets,
    vendoredSchemas: Object.fromEntries(manifest.schemas.map((entry) => [entry.id, {
      sourceUrl: entry.sourceUrl,
      sourceVersion: entry.sourceVersion,
      sourceSha256: entry.sourceSha256,
      vendoredSha256: entry.vendoredSha256,
      retrievedAt: manifest.retrievedAt,
    }])),
  };
  const compatibilityDigest = sha256(stableJSON(compatibilityBase));
  const compatibility = `${stableJSON({ ...compatibilityBase, compatibilityDigest }, 2)}\n`;

  const outputs = new Map<string, string>([
    [outputPaths.catalog, generateCatalog(loaded)],
    [outputPaths.typescript, generateTypeScript(models, byID, records, permissionSets, schemaDigest, compatibilityDigest, manifest)],
    [outputPaths.swiftPackage, generateSwift(models, byID, records, permissionSets, schemaDigest, compatibilityDigest, manifest)],
    [outputPaths.swiftApple, generateSwift(models, byID, records, permissionSets, schemaDigest, compatibilityDigest, manifest)],
    [outputPaths.kotlin, generateKotlin(models, byID, records, permissionSets, schemaDigest, compatibilityDigest, manifest)],
    [outputPaths.compatibility, compatibility],
  ]);

  const stale: string[] = [];
  for (const [path, source] of outputs) {
    const existing = await readFile(path, "utf8").catch(() => "");
    if (existing === source) continue;
    if (checkMode) {
      stale.push(posixPath(relative(repositoryRoot, path)));
    } else {
      await mkdir(dirname(path), { recursive: true });
      await writeFile(path, source);
    }
  }

  if (stale.length > 0) {
    console.error(`Generated Lexicon outputs are stale:\n${stale.map((path) => `  - ${path}`).join("\n")}\nRun \`bun run --cwd packages/lexicons generate\`.`);
    process.exitCode = 1;
  } else if (!checkMode) {
    console.log(`Generated ${outputs.size} outputs from ${loaded.length} offline Lexicon schemas.`);
  }
}

await main();
