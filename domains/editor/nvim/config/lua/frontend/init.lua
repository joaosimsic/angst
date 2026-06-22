local Spec = require("common.Spec")

local specs = Spec.merge({
	require("frontend.navigation"),
	require("frontend.status"),
})

return specs
