import './style.css'
import javascriptLogo from './javascript.svg'
import viteLogo from './vite.svg'
import bazellogo from './bazel.svg'
import { setupCounter } from './counter.js'

document.querySelector('#app').innerHTML = `
  <div>
    <a href="https://developer.mozilla.org/en-US/docs/Web/JavaScript" target="_blank">
      <img src="${javascriptLogo}" class="logo vanilla" alt="JavaScript logo" />
    </a>
    <a href="https://vite.dev" target="_blank">
      <img src="${viteLogo}" class="logo vite" alt="Vite logo" />
    </a>
    <a href="https://bazel.build" target="_blank">
      <img src="${bazellogo}" class="logo bazel" alt="Bazel logo" />
    </a>
    <h1>Vite for bazel is here!</h1>
    <div class="card">
      <button id="counter" type="button"></button>
    </div>
    <p class="read-the-docs">
      Click on logos to learn more
    </p>
  </div>
`

setupCounter(document.querySelector('#counter'))
