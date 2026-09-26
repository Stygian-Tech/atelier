import { fixupConfigRules } from "@eslint/compat";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

export default [
  ...fixupConfigRules([...nextVitals, ...nextTs]),
  { rules: { "@next/next/no-html-link-for-pages": "off" } },
];
