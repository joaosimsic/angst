let
  strings = import ../../lib/strings.nix;
  errors = import ./errors.nix;

  mkSecretRefValidation =
    inventory:
    let
      isRefAttrs = value: builtins.isAttrs value && builtins.attrNames value == [ "ref" ];

      isSecretRef = value: isRefAttrs value && strings.isNonEmptyString (value.ref or null);

      isScalar =
        value:
        builtins.elem (builtins.typeOf value) [
          "null"
          "bool"
          "int"
          "float"
          "string"
        ];

      isKnownSecretRef = ref: strings.isNonEmptyString ref && builtins.elem ref inventory.secretSlugs;

      checkSecretFields =
        secretFields:
        if
          builtins.isList secretFields && builtins.all (field: strings.isNonEmptyString field) secretFields
        then
          secretFields
        else
          errors.throwSecretFields { field = "secretFields"; };

      isDeclared =
        secretFields: path: name:
        builtins.elem name secretFields || builtins.elem (path + "." + name) secretFields;

      walkDeclared =
        context: value:
        if isSecretRef value then
          if isKnownSecretRef value.ref then value else errors.throwUnknownRef context value.ref
        else if isRefAttrs value then
          errors.throwBadRef context
        else
          errors.throwField context;

      checkSecretRef = ref: walkDeclared { field = "ref"; } { inherit ref; };

      walkList =
        secretFields: path: value:
        builtins.genList (
          index: walk secretFields (path + "." + toString index) false (builtins.elemAt value index)
        ) (builtins.length value);

      walkRefAttrs =
        path: value:
        if isSecretRef value then
          errors.throwMisplaced { inherit path; }
        else
          errors.throwBadRef { inherit path; };

      walkAttrs =
        secretFields: path: value:
        builtins.mapAttrs (
          name: child: walk secretFields (path + "." + name) (isDeclared secretFields path name) child
        ) value;

      walk =
        secretFields: path: declared: value:
        if declared then
          walkDeclared { inherit path; } value
        else if isScalar value then
          value
        else if builtins.isList value then
          walkList secretFields path value
        else if isRefAttrs value then
          walkRefAttrs path value
        else if builtins.isAttrs value then
          walkAttrs secretFields path value
        else
          errors.throwUnsupported { inherit path; };

      checkSecretRefsIn =
        {
          data,
          secretFields ? inventory.secretSlugs,
        }:
        let
          declaredFields = checkSecretFields secretFields;
          validatedData = walk declaredFields "data" false data;
        in
        builtins.deepSeq declaredFields (builtins.deepSeq validatedData validatedData);

      checkSecretRefsOnly = data: checkSecretRefsIn { inherit data; };
    in
    {
      inherit
        checkSecretRef
        isSecretRef
        isKnownSecretRef
        checkSecretRefsOnly
        checkSecretRefsIn
        ;
    };
in
{
  inherit mkSecretRefValidation;
}
