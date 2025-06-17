import './style.css'
import typescriptLogo from '/typescript.svg'
import viteLogo from '/vite.svg'
import bazellogo from '/bazel.svg'
import { setupCounter } from './counter.ts'

document.querySelector<HTMLDivElement>('#app')!.innerHTML = `
  <div>
    <a href="https://vite.dev" target="_blank">
      <img src="${viteLogo}" class="logo vite" alt="Vite logo" />
    </a>
    <a href="https://www.typescriptlang.org/" target="_blank">
      <img src="${typescriptLogo}" class="logo typescript" alt="TypeScript logo" />
    </a>
    <a href="https://bazel.build/" target="_blank">
      <img src="${bazellogo}" class="logo bazel" alt="Bazel logo" />
    </a>
    <h1>Vite + TypeScript + Bazel</h1>
    <div class="card">
      <button id="counter" type="button"></button>
    </div>
    <p class="read-the-docs">
      Click on the Vite, TypeScript, or Bazel logos to learn more
    </p>
  </div>
`

setupCounter(document.querySelector<HTMLButtonElement>('#counter')!)
