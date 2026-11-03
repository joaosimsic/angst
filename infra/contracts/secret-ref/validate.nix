let
  strings = import ../../lib/strings.nix;
  errors = import ./errors.nix;

  mkSecretRefValidation =
    inventory:
    let
      nameSet =
        names:
        builtins.listToAttrs (
          map (name: {
            inherit name;
            value = true;
          }) names
        );

      slugSet = nameSet inventory.secretSlugs;

      isRefAttrs = value: builtins.isAttrs value && builtins.attrNames value == [ "ref" ];

      isSecretRef = value: isRefAttrs value && strings.isNonEmptyString (value.ref or null);

      isScalar =
        value:
        value == null
        || builtins.isBool value
        || builtins.isInt value
        || builtins.isFloat value
        || builtins.isString value;

      isKnownSecretRef = ref: builtins.isString ref && ref != "" && builtins.hasAttr ref slugSet;

      checkSecretRef =
        ref:
        if isKnownSecretRef ref then
          { inherit ref; }
        else if !strings.isNonEmptyString ref then
          errors.throwBadRef { field = "ref"; }
        else
          errors.throwUnknownRef { field = "ref"; } ref;

      checkSecretFields =
        secretFields:
        if
          builtins.isList secretFields && builtins.all (field: strings.isNonEmptyString field) secretFields
        then
          nameSet secretFields
        else
          errors.throwSecretFields { field = "secretFields"; };

      isDeclared =
        fieldSet: path: name:
        builtins.hasAttr name fieldSet || builtins.hasAttr (path + "." + name) fieldSet;

      walkDeclared =
        path: value:
        if isSecretRef value then
          if isKnownSecretRef value.ref then value else errors.throwUnknownRef { inherit path; } value.ref
        else if isRefAttrs value then
          errors.throwBadRef { inherit path; }
        else
          errors.throwField { inherit path; };

      walkList =
        fieldSet: path: value:
        builtins.genList (
          index: walk fieldSet (path + "." + toString index) false (builtins.elemAt value index)
        ) (builtins.length value);

      walkAttr =
        fieldSet: path: name: value:
        let
          childPath = path + "." + name;
        in
        walk fieldSet childPath (isDeclared fieldSet path name) value;

      walkAttrs =
        fieldSet: path: value:
        if isRefAttrs value then
          if isSecretRef value then
            errors.throwMisplaced { inherit path; }
          else
            errors.throwBadRef { inherit path; }
        else
          builtins.listToAttrs (
            map (name: {
              inherit name;
              value = walkAttr fieldSet path name value.${name};
            }) (builtins.attrNames value)
          );

      walk =
        fieldSet: path: declared: value:
        if declared then
          walkDeclared path value
        else if isScalar value then
          value
        else if builtins.isList value then
          walkList fieldSet path value
        else if builtins.isAttrs value then
          walkAttrs fieldSet path value
        else
          errors.throwUnsupported { inherit path; };

      checkSecretRefsIn =
        {
          data,
          secretFields ? inventory.secretSlugs,
        }:
        let
          fieldSet = checkSecretFields secretFields;
          validatedData = walk fieldSet "data" false data;
        in
        builtins.deepSeq fieldSet (builtins.deepSeq validatedData validatedData);

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
