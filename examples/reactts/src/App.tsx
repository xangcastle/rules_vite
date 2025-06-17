import { useState } from 'react'
import reactLogo from './assets/react.svg'
import viteLogo from '/vite.svg'
import typescriptLogo from '/typescript.svg'
import bazelLogo from '/bazel.svg'
import { MyButton } from '@packages/mybutton'
import './App.css'

function App() {
  const [count, setCount] = useState(0)

  return (
    <>
      <div>
        <a href="https://vite.dev" target="_blank">
          <img src={viteLogo} className="logo vite" alt="Vite logo" />
        </a>
        <a href="https://www.typescriptlang.org/" target="_blank">
          <img src={typescriptLogo} className="logo typescript" alt="Typescript logo" />
        </a>
        <a href="https://react.dev" target="_blank">
          <img src={reactLogo} className="logo react" alt="React logo" />
        </a>
        <a href="https://react.dev" target="_blank">
          <img src={bazelLogo} className="logo bazel" alt="Bazel logo" />
        </a>
      </div>
      <h1>Vite + Typescript + React + Bazel</h1>
      <div className="card">
        <MyButton onClick={() => setCount((count) => count + 1)}>
          count is {count}
        </MyButton>
        <div style={{ marginTop: '16px', display: 'flex', gap: '8px', justifyContent: 'center' }}>
          <MyButton variant="secondary" size="small">Small</MyButton>
          <MyButton variant="danger" size="large">Large Danger</MyButton>
          <MyButton disabled>Disabled</MyButton>
        </div>
        <p>
          Edit <code>src/App.tsx</code> and save to test HMR
        </p>
      </div>
      <p className="read-the-docs">
        Click on the Vite, Typescript, React, or Bazel logos to learn more
      </p>
    </>
  )
}

export default App
