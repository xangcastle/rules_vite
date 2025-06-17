<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Rules for vite

<a id="vite_binary"></a>

## vite_binary

<pre>
vite_binary(<a href="#vite_binary-name">name</a>, <a href="#vite_binary-deps">deps</a>, <a href="#vite_binary-srcs">srcs</a>, <a href="#vite_binary-vite_cli">vite_cli</a>, <a href="#vite_binary-vite_config">vite_config</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vite_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vite_binary-deps"></a>deps |  List of node_modules dependencies   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="vite_binary-srcs"></a>srcs |  Additional source files needed for the application   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="vite_binary-vite_cli"></a>vite_cli |  The vite CLI tool to use for bundling the application   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>//tools/vite:vite_cli</code> |
| <a id="vite_binary-vite_config"></a>vite_config |  Custom vite config file.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |


<a id="vite_test"></a>

## vite_test

<pre>
vite_test(<a href="#vite_test-name">name</a>, <a href="#vite_test-deps">deps</a>, <a href="#vite_test-srcs">srcs</a>, <a href="#vite_test-vite_config">vite_config</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vite_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vite_test-deps"></a>deps |  A list of <code>node_modules</code> dependencies required by the test. These are typically targets from the root <code>BUILD.bazel</code> file (e.g., <code>//:node_modules/@testing-library/react</code>).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="vite_test-srcs"></a>srcs |  A list of source files, test files, and any other assets needed for the test to run. This should include all transitive source files, such as <code>.css</code> files, SVGs, and <code>tsconfig.json</code> files if applicable.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="vite_test-vite_config"></a>vite_config |  The <code>vitest.config.ts</code> (or <code>.js</code>, <code>.mjs</code>) file for the test. This file is made available in the runfiles and will be found by Vitest by convention, as the test root is set to the package directory.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


