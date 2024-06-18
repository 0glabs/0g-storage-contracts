module.exports = {
    env: {
        browser: true,
        es2021: true,
        node: true,
    },
    extends: [
        "eslint:recommended",
        "plugin:@typescript-eslint/strict-type-checked",
        "plugin:prettier/recommended",
    ],
    overrides: [],
    parser: "@typescript-eslint/parser",
    parserOptions: {
        ecmaVersion: "latest",
        project: true,
        sourceType: "module",
    },
    plugins: ["@typescript-eslint", "no-only-tests"],
    rules: {
        eqeqeq: "error",
        "@typescript-eslint/consistent-type-imports": [
            "error",
            { prefer: "no-type-imports" },
        ],
    },
    ignorePatterns: [".eslintrc.js"],
};
