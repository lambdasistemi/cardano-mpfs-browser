export const readApiBaseUrlImpl = (just) => (nothing) => () => {
  if (typeof window === "undefined") {
    return nothing;
  }

  const baseUrl = window.MPFS_BASE_URL;
  if (typeof baseUrl !== "string" || baseUrl === "") {
    return nothing;
  }

  return just(baseUrl);
};
