export interface LazyWindowComponent {
  readonly kind: "lazy-window-component";
  readonly name: string;
  load(): Promise<any>;
}

/** Keep a window's component code unloaded until its content is mounted. */
export function lazyWindowComponent(
  name: string,
  loader: () => Promise<{ default: any }>,
): LazyWindowComponent {
  let pending: Promise<any> | undefined;

  return {
    kind: "lazy-window-component",
    name,
    load() {
      if (!pending) {
        pending = loader()
          .then((module) => module.default)
          .catch((error) => {
            // A failed download must not prevent a later retry.
            pending = undefined;
            throw error;
          });
      }
      return pending;
    },
  };
}

export function isLazyWindowComponent(
  component: unknown,
): component is LazyWindowComponent {
  return (
    component !== null &&
    typeof component === "object" &&
    (component as LazyWindowComponent).kind === "lazy-window-component" &&
    typeof (component as LazyWindowComponent).load === "function"
  );
}
