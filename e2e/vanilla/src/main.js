function render() {
  const app = document.querySelector("#app");
  app.innerHTML = "<h1>rules_vite vanilla example</h1>";
  app.dataset.greeting = import.meta.env.VITE_GREETING ?? "missing";
  app.dataset.stage = import.meta.env.VITE_STAGE ?? "missing";
}

render();
