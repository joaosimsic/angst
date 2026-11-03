let
  renderContext =
    context:
    let
      names = builtins.attrNames context;
      rendered = builtins.concatStringsSep " " (
        map (name: "${name}=${builtins.toJSON context.${name}}") names
      );
    in
    if names == [ ] then "" else " (${rendered})";

  formatError =
    {
      kind ? "error",
      message,
      context ? { },
      causes ? [ ],
    }:
    let
      renderedCauses = map (
        cause: "  " + builtins.replaceStrings [ "\n" ] [ "\n  " ] (formatError cause)
      ) causes;
      causeSuffix =
        if renderedCauses == [ ] then "" else "\n" + builtins.concatStringsSep "\n" renderedCauses;
    in
    "error[${kind}]: ${message}${renderContext context}${causeSuffix}";

  throwError = error: throw (formatError error);
in
{
  inherit throwError;
}
