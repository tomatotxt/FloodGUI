local create = require("../overrides")
local overrides = create()
local humanoid = { WalkSpeed = 16, JumpPower = 50, MaxHealth = 100, Health = 80 }
overrides.set(humanoid, "WalkSpeed", 30)
overrides.set(humanoid, "WalkSpeed", 40)
assert(overrides.restore(humanoid, "WalkSpeed") and humanoid.WalkSpeed == 16)
overrides.set(humanoid, "JumpPower", 100)
humanoid.JumpPower = 0
overrides.restore(humanoid, "JumpPower")
assert(humanoid.JumpPower == 0, "game change must survive cleanup")
overrides.set(humanoid, "MaxHealth", 100000)
humanoid.Health = 100000
overrides.restoreAll()
assert(humanoid.MaxHealth == 100 and humanoid.Health == 100)
assert(not overrides.restore(humanoid, "WalkSpeed"))
print(
	"PASS: reversible movement overrides, original values preserved across edits, external changes respected, health cleanup"
)
