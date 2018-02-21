STRUCTURE_STRING = 0
STRUCTURE_ANGLE  = 1
STRUCTURE_VECTOR = 2
STRUCTURE_COLOR  = 3
STRUCTURE_ENTITY = 4
STRUCTURE_BIT    = 5
STRUCTURE_BOOL   = 6
STRUCTURE_NUMBER = 7
STRUCTURE_INT8   = 8
STRUCTURE_INT16  = 9
STRUCTURE_INT32  = 10
STRUCTURE_UINT8  = 11
STRUCTURE_UINT16 = 12
STRUCTURE_UINT32 = 13

local structures = {}
local structureType = {
	[STRUCTURE_STRING] = {
		name = "string",
		predicate = function(v) return isstring(v) end,
		write = net.WriteString,
		read = net.ReadString
	},

	[STRUCTURE_ANGLE] = {
		name = "angle",
		predicate = function(v) return isangle(v) end,
		write = net.WriteAngle,
		read = net.ReadAngle
	},

	[STRUCTURE_VECTOR] = {
		name = "vector",
		predicate = function(v) return isvector(v) end,
		write = net.WriteVector,
		read = net.ReadVector
	},

	[STRUCTURE_COLOR] = {
		name = "color",
		predicate = function(v) return IsColor(v) end,
		write = net.WriteColor,
		read = net.ReadColor
	},

	[STRUCTURE_ENTITY] = {
		name = "entity",
		predicate = function(v) return IsValid(v) or v == game.GetWorld() end,
		write = net.WriteEntity,
		read = net.ReadEntity
	},

	[STRUCTURE_BIT] = {
		name = "bit",
		predicate = function(v) return isbool(v) or v == 0 or v == 1 end,
		write = net.WriteBit,
		read = net.ReadBit
	},

	[STRUCTURE_BOOL] = {
		name = "bool",
		predicate = function(v) return isbool(v) or v == 0 or v == 1 end,
		write = net.WriteBool,
		read = net.ReadBool
	},

	[STRUCTURE_NUMBER] = {
		name = "number",
		predicate = function(v) return isnumber(v) end,
		write = net.WriteDouble,
		read = net.ReadDouble
	},

	[STRUCTURE_INT8] = {
		name = "int8",
		predicate = function(v) return isnumber(v) and v >= -128 and v <= 127 end,
		write = function(v) net.WriteInt(v, 8) end,
		read = function() return net.ReadInt(8) end
	},

	[STRUCTURE_INT16] = {
		name = "int16",
		predicate = function(v) return isnumber(v) and v >= -32768 and v <= 32767 end,
		write = function(v) net.WriteInt(v, 16) end,
		read = function() return net.ReadInt(16) end
	},

	[STRUCTURE_INT32] = {
		name = "int32",
		predicate = function(v) return isnumber(v) and v >= -2147483648 and v <= 2147483647 end,
		write = function(v) net.WriteInt(v, 32) end,
		read = function() return net.ReadInt(32) end
	},

	[STRUCTURE_UINT8] = {
		name = "uint8",
		predicate = function(v) return isnumber(v) and v >= 0 and v <= 255 end,
		write = function(v) net.WriteUInt(v, 8) end,
		read = function() return net.ReadUInt(8) end
	},

	[STRUCTURE_UINT16] = {
		name = "uint16",
		predicate = function(v) return isnumber(v) and v >= 0 and v <=  65535 end,
		write = function(v) net.WriteUInt(v, 16) end,
		read = function() return net.ReadUInt(16) end
	},

	[STRUCTURE_UINT32] = {
		name = "uint32",
		predicate = function(v) return isnumber(v) and v >= 0 and v <= 4294967295 end,
		write = function(v) net.WriteUInt(v, 32) end,
		read = function() return net.ReadUInt(32) end
	}
}

function net.RegisterType(name, data)
	assert(isstring(name), "Structure type names must be strings")
	assert(not istable(structureType[name]), Format([[Structure type "%s" already exists]], name))
	assert(not istable(structures[name]), Format([[A Structure exists with the name "%s"]], name))
	assert(istable(data), "Structure type data must be a table")
	assert(isstring(data.name), "Structure type data must have a name string")
	assert(isfunction(data.predicate), "Structure type data must have a predicate function")
	assert(isfunction(data.write), "Structure type data must have a write function")
	assert(isfunction(data.read), "Structure type data must have a read function")

	structureType[name] = data
end

function net.RegisterStructure(name, structure)
	assert(isstring(name), "Structure name must be a string")
	assert(not istable(structures[name]), Format([[Structure "%s" already exists]], name))
	assert(not istable(structureType[name]), Format([[A Structure type exists with the name "%s"]], name))
	assert(istable(structure), "Structure must be a table")

	if (table.IsSequential(structure)) then
		assert(#structure == 1, "Sequential Structures must contain only 1 element")

		local element = structure[1]

		assert(istable(structures[element]) or istable(structureType[element]), Format("Invalid Sequential Structure Type: \"%s\". Sequential Structure elements must be a STRUCTURE_* value, Structure reference or Structure type", element))
	else
		for k, v in SortedPairs(structure) do
			if (istable(v)) then
				assert(table.IsSequential(v), Format("Structure tables must be sequential (at index %s)", k))
				assert(#v == 1, Format("Structure tables must contain only 1 element (at index %s)", k))

				local element = v[1]

				if (isnumber(element)) then
					assert(element >= 0 and element <= 12, Format("Structure table element number value must be a STRUCTURE_* value (at index %s)", k))
				elseif (isstring(element)) then
					assert(istable(structures[element]) or istable(structureType[element]), Format("Structure table element string value must refer to a Structure Reference or Structure type (at index %s)", k))
				else
					assert(false, Format("Structure table elements must be STRUCTURE_* values, Structure References or Structure types (at index %s)", k))
				end
			elseif (isstring(v)) then
				assert(istable(structures[v]) or istable(structureType[v]), "Structure string values must refer to a Structure or Structure type")
				assert(v ~= name, "Structure references cannot refer to the Structure containing them")
			else
				assert(isnumber(v), Format("Structure values must be numbers (at index %s)", k))
				assert(v >= 0 and v <= 12, Format("Structure values must be STRUCTURE_* values (at index %s)", k))
			end
		end
	end

	structures[name] = structure
end

local function writeSequentialTable(structType, tbl)
	assert(table.IsSequential(tbl), "Structure tables must be sequential")

	local count = #tbl
	net.WriteUInt(count, 32)

	for index = 1, count do
		if (istable(structureType[structType])) then
			local typeData = structureType[structType]

			local element = tbl[index];
			local valueString = tostring(element);

			// Error messages cannot contain square brackets without it ruining everything.
			// Why? Because Garry's Mod.
			if (IsValid(element) or element == game.GetWorld()) then
				if (element:IsPlayer()) then
					valueString = Format("Player (%i) %s", element:EntIndex(), element:Name());
				else
					valueString = Format("Entity (%i) %s", element:EntIndex(), element:GetClass());
				end
			end

			assert(typeData.predicate(tbl[index]), Format("Structure table value (%s:%s) does not match predicate of %s (at index %i)", valueString, type(tbl[index]), typeData.name, index))
			typeData.write(tbl[index])
		elseif (istable(structures[structType])) then
			net.WriteStructure(structType, tbl[index])
		end
	end
end

local function readSequentialTable(structType)
	local count = net.ReadUInt(32)

	local array = {}
	for i = 1, count do
		if (istable(structureType[structType])) then
			array[i] = structureType[structType].read()
		elseif (istable(structures[structType])) then
			array[i] = net.ReadStructure(structType)
		end
	end

	return array
end

function net.WriteStructure(name, structure)
	assert(isstring(name), "Structure name must me a string")
	assert(istable(structure), "Structure must be a table")
	assert(istable(structures[name]), Format([[Invalid structure "%s"]], name))

	local structureData = structures[name]

	if (table.IsSequential(structureData)) then
		writeSequentialTable(structureData[1], structure)
	else
		for k,v in SortedPairs(structureData) do
			local value = structure[k]

			assert(value ~= nil, Format("Structure table missing index for %s", k))

			if (istable(structureType[v])) then
				local typeData = structureType[v]
				assert(typeData.predicate(value), Format("Structure value does not match predicate of %s (at index %s)", typeData.name, k))
				typeData.write(value)
			elseif (istable(structures[v])) then
				net.WriteStructure(v, structure[k])
			elseif (istable(v)) then
				writeSequentialTable(v[1], structure[k])
			end
		end
	end
end

function net.ReadStructure(name)
	assert(isstring(name), "Structure name must me a string")
	assert(istable(structures[name]), Format([[Invalid structure "%s"]], name))

	local structure = structures[name]

	if (table.IsSequential(structure)) then
		return readSequentialTable(structure[1])
	else
		local ret = {}

		for k,v in SortedPairs(structure) do
			if (istable(structures[v])) then
				ret[k] = net.ReadStructure(v)
			elseif (istable(structureType[v])) then
				ret[k] = structureType[v].read()
			else
				if (istable(v)) then
					ret[k] = readSequentialTable(v[1])
				else --if (isstring(v) and istable(structures[v])) then
					ret[k] = structureType[v].read()
				end
			end
		end

		return ret
	end
end