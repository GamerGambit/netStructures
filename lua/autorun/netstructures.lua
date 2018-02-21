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
		predicate = function(v) return IsValid(v) end,
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

	for k, v in SortedPairs(structure) do
		if (istable(v)) then
			assert(table.IsSequential(v), Format("Structure tables must be sequential (at index %s)", k))
			assert(#v == 1, Format("Structure tables must contain only 1 element (at index %s)", k))

			local element = v[1]

			if (isnumber(element)) then
				assert(element >= 0 and element <= 12, Format("Structure table element number value must be a STRUCTURE_* value (at index %s)", k))
			elseif (isstring(element)) then
				if (not istable(structures[element]) and not istable(structureType[element])) then
					assert(false, Format("Structure table element string value must refer to a Structure Reference or Structure type (at index %s)", k))
				end
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

	structures[name] = structure
end

function net.WriteStructure(name, structure)
	assert(isstring(name), "Structure name must me a string")
	assert(istable(structure), "Structure must be a table")
	assert(istable(structures[name]), Format([[Invalid structure "%s"]], name))

	for k,v in SortedPairs(structures[name]) do
		local value = structure[k]

		assert(value ~= nil, Format("Structure table missing index for %s", k))

		if (istable(structureType[v])) then
			local typeData = structureType[v]
			assert(typeData.predicate(value), Format("Structure value does not match predicate of %s (at index %s)", typeData.name, k))
			typeData.write(value)
		elseif (istable(structures[v])) then
			net.WriteStructure(v, structure[k])
		elseif (istable(v)) then
			assert(table.IsSequential(value), "Structure tables must be sequential")

			local count = #value
			net.WriteUInt(count, 32)

			for index = 1, count do
				if (istable(structureType[v[1]])) then
					local typeData = structureType[v[1]]
					assert(typeData.predicate(value[index]), Format("Structure table value does not match predicate of %s (at index %s:%i)", typeData.name, k, index))
					typeData.write(value[index])
				elseif (istable(structures[v[1]])) then
					net.WriteStructure(v[1], value[index])
				end
			end
		end
	end
end

function net.ReadStructure(name)
	assert(isstring(name), "Structure name must me a string")
	assert(istable(structures[name]), Format([[Invalid structure "%s"]], name))

	local ret = {}

	for k,v in SortedPairs(structures[name]) do
		if (istable(structures[v])) then
			ret[k] = net.ReadStructure(v)
		elseif (istable(structureType[v])) then
			ret[k] = structureType[v].read()
		else
			if (istable(v)) then
				local count = net.ReadUInt(32)

				local array = {}
				for i = 1, count do
					if (istable(structureType[v[1]])) then
						array[i] = structureType[v[1]].read()
					elseif (istable(structures[v[1]])) then
						array[i] = net.ReadStructure(v[1])
					end
				end

				ret[k] = array
			else --if (isstring(v) and istable(structures[v])) then
				ret[k] = structureType[v].read()
			end
		end
	end

	return ret
end