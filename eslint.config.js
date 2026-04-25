import js from "@eslint/js";
import prettierConfig from "eslint-config-prettier";

export default [
  js.configs.recommended,
  prettierConfig,
  {
    files: ["frontend/src/**/*.js"],
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: "module",
      globals: {
        window: "readonly",
        document: "readonly",
        localStorage: "readonly",
        console: "readonly",
      },
    },
    rules: {
      "no-console": "warn",
      "no-unused-vars": ["error", { argsIgnorePattern: "^_", caughtErrorsIgnorePattern: "^_" }],
    },
  },
  {
    files: ["backend/pb_hooks/**/*.js"],
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: "script",
      globals: {
        $app: "readonly",
        onRecordAfterCreateSuccess: "readonly",
        onRecordAfterUpdateSuccess: "readonly",
        onRecordAfterDeleteSuccess: "readonly",
        onRecordAuthRequest: "readonly",
        onRecordCreateRequest: "readonly",
        ForbiddenError: "readonly",
        BadRequestError: "readonly",
        Record: "readonly",
        console: "readonly",
      },
    },
    rules: {
      "no-console": "warn",
      "no-unused-vars": ["error", { argsIgnorePattern: "^_", caughtErrorsIgnorePattern: "^_" }],
    },
  },
];
