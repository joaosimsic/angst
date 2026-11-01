let
  types = import ../../lib/types.nix;
  errors = import ./errors.nix;

  mk =
    inventory:
    let
      result = inventory.inventoryResult;
      slugSet = builtins.listToAttrs (
        map (slug: {
          name = slug;
          value = true;
        }) inventory.secretSlugs
      );
      inventoryErr = types.isErr result;

      badRef = errors.badRef;
      unknownRef = errors.unknownRef;
      fieldError = errors.field;
      misplaced = errors.misplaced;
      unsupported = errors.unsupported;

      isSecretRef =
        value:
        builtins.isAttrs value
        && builtins.attrNames value == [ "ref" ]
        && types.isNonEmptyStr (value.ref or null);

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
        if inventoryErr then
          types.withContext { field = "ref"; } result
        else if types.isNonEmptyStr ref && builtins.hasAttr ref slugSet then
          types.ok { inherit ref; }
        else if !types.isNonEmptyStr ref then
          badRef { field = "ref"; }
        else
          unknownRef { field = "ref"; } ref;

      checkSecretFields =
        secretFields:
        if builtins.isList secretFields && builtins.all types.isNonEmptyStr secretFields then
          types.ok (
            builtins.listToAttrs (
              map (name: {
                name = name;
                value = true;
              }) secretFields
            )
          )
        else
          errors.secretFields { field = "secretFields"; };

      isDeclared =
        fieldSet: path: name:
        builtins.hasAttr name fieldSet || builtins.hasAttr (path + "." + name) fieldSet;

      walk =
        fieldSet: path: declared: value:
        if declared then
          if inventoryErr then
            types.withContext { inherit path; } result
          else if isSecretRef value then
            if builtins.hasAttr value.ref slugSet then types.ok true else unknownRef { inherit path; } value.ref
          else if builtins.isAttrs value && builtins.attrNames value == [ "ref" ] then
            badRef { inherit path; }
          else
            fieldError { inherit path; }
        else if isScalar value then
          types.ok true
        else if builtins.isList value then
          types.mapOk (_: true) (
            types.collect (
              builtins.genList (i: walk fieldSet (path + "." + toString i) false (builtins.elemAt value i)) (
                builtins.length value
              )
            )
          )
        else if builtins.isAttrs value && builtins.attrNames value == [ "ref" ] then
          if isSecretRef value then misplaced { inherit path; } else badRef { inherit path; }
        else if builtins.isAttrs value then
          types.mapOk (_: true) (
            types.collect (
              map (
                name:
                let
                  childPath = path + "." + name;
                in
                walk fieldSet childPath (isDeclared fieldSet path name) value.${name}
              ) (builtins.attrNames value)
            )
          )
        else
          unsupported { inherit path; };

      checkSecretRefsIn =
        {
          data,
          secretFields ? inventory.secretSlugs,
        }:
        if inventoryErr then
          result
        else
          types.andThen (fieldSet: walk fieldSet "data" false data) (checkSecretFields secretFields);

      checkSecretRefsOnly = data: checkSecretRefsIn { inherit data; };
    in
    {
      inherit checkSecretRef;
      inherit isSecretRef;
      inherit isKnownSecretRef;
      inherit checkSecretRefsOnly;
      inherit checkSecretRefsIn;
    };
in
{
  inherit mk;
}
