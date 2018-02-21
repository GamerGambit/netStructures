# netStructures
Garry's Mod library for networking tables.

`net.ReadTable` and `net.WriteTable` are functions in the Garry's Mod net library tasked with networking a table of arbitrary data. Any Garry's Mod programmer worth their salt will know that these functions suck; they send more data than is really needed due to the fact that Lua and Garry's Mod cant know the structure of a table.

Enter **netStructures**. **netStructures** introduces a way to send and receive tables of predefined structure in super friendly way.

Why would you want to predefine your table structures for networking? Strict, consistent structure in code is important whether its for networking or not. It can also help immensely with debugging. If the structure of the table you are sending is known, it means the type information that `net.Read/Write` table use can be omitted, thus only sending the data that is needed and reducing network data.

**netStructures** works by having the user "register" a table structure. This structure can then be used with the `net.WriteStructure` and `net.ReadStructure` functions. These 2 functions are almost a copy/paste replacement for net.Read/WriteTable.

## Preamble: **netStructures** Type Enums
In order for netStructures to know which keys in your table correspond to which values, **netStructures** defines 13 global integral values for primitive types commonly used in networking:

```
STRUCTURE_STRING
STRUCTURE_ANGLE
STRUCTURE_VECTOR
STRUCTURE_COLOR
STRUCTURE_ENTITY
STRUCTURE_BIT
STRUCTURE_NUMBER -- Generic; floating point
STRUCTURE_INT8 -- Integer values between -128 and 127
STRUCTURE_INT16 -- Integer values between -32768 and 32767
STRUCTURE_INT32 -- Integer values between -2147483648 and 2147483647
STRUCTURE_UINT8 -- Integer values between 0 and 255
STRUCTURE_UINT16 -- Integer values between 0 and 65535
STRUCTURE_UINT32 -- Integer values between 0 and 4294967295
```

## Step 1:  Registration
The first step to using netStructures is to register your table structure:
```
net.RegisterStructure("my_struct_weps", {
	name = STRUCTURE_STRING,
	ammo = STRUCTURE_NUMBER
})
```

The code above says to create a new structure called "my\_struct\_weps" with 2 fields: a name string and an ammo number. When this structure is used, **netStructures** will enforce these types on the values provided by the table.

## Step 2:  Write the structure
Writing structures is almost identical to `net.WriteTable`:
```
net.WriteStructure("my_struct_weps", {
	name = "pistol",
	ammo = 10
})
```

The first argument in `net.WriteStructure` tells **netStructs** which structure to use. In this example we are using the structure we created before.

When `net.WriteStructure` is called, it will make sure that the name you have provided is an actual struct, then it will make sure that the table you have provided matches the structure.

## Step 3:  Reading the structure
Like writing, reading structures is almost identical to `net.ReadTable`:
```
local wep = net.ReadStructure("my_struct_weps")
```

`wep` will be a table containing `name = "pistol", ammo = 10`.

**netStructures** provides fixed-width integer types which are not wrapped. If you provide a value that is outside of the range specified in the structure, it will error.

**netStructures** allows fields to reference other structures:
```
net.RegisterStructure("my_struct", {
	name = STRUCTURE_STRING,
	weapon = "my_struct_weps"
})
```

The above code creates a new structure where weapon refers to the structure we created earlier. This is known as a *Structure Reference*. This new structure can be networked like so:
```
net.WriteStructure("my_struct", {
	name = "Gambit",
	weapon = {
		name = "pistol",
		ammo = 10
	}
})
```

**netStructures** also lets structures define sequential arrays. Arrays must be homogeneous, using the `STRUCTURE_*` enums or *Structure References*:
```
net.RegisterStructure("my_struct", {
	name = STRUCTURE_STRING,
	weapons = {"my_struct_weps"} -- denotes that `items` is a sequential array of the "my_struct_weps" structure
})

net.WriteStructure("my_struct", {
	name = "Gambit",
	weapons = {
		{
			name = "pistol",
			ammo = 10
		}
	}
})
```

With the complete sample program, here are some results:
```
net.RegisterStructure("my_struct_weps", {
	name = STRUCTURE_STRING,
	ammo = STRUCTURE_NUMBER
})

net.RegisterStructure("my_struct", {
	name = STRUCTURE_STRING,
	items = {"my_struct_weps"} -- denotes that `items` is a sequential array of the "my_struct_weps" structure
})

if (SERVER) then
	util.AddNetworkString("my_struct_nws")
	util.AddNetworkString("my_struct_nws_tbl")
	
	function netStructureTest(ply)
		net.Start("my_struct_nws")
			net.WriteStructure("my_struct", {
				name = "Gambit",
				items = {
					{
						name = "pistol",
						ammo = 10
					}
				}
			})
		net.Send(ply)
		
		net.Start("my_struct_nws_tbl")
			net.WriteTable({
				name = "Gambit",
				items = {
					{
						name = "pistol",
						ammo = 10
					}
				}
			})
		net.Send(ply)
	end
else
	net.Receive("my_struct_nws", function(l)
		print("net.ReadStructure", l)
		PrintTable(net.ReadStructure("my_struct"))
	end)
	
	net.Receive("my_struct_nws_tbl", function(l)
		print("net.ReadTable", l)
		PrintTable(net.ReadTable())
	end)
end
```
```
net.ReadStructure	208
items:
		1:
				ammo	=	10
				name	=	pistol
name	=	Gambit
net.ReadTable	512
items:
		1:
				ammo	=	10
				name	=	pistol
name	=	Gambit
```

In this example, we can see an almost 2.5x improvement on size compared to `net.Read/WriteTable`. Other tables and structures I have tested have yielded upwards of 3.5x so your mileage may vary.

## Custom Structure Types
**netStructures** allows you to register custom types in the event that using the built-in `STRUCTURE_*` enums is not enough.
```
net.RegisterType("matrix", {
	name = "matrix",
	predicate = function(v) return ismatrix(v) end,
	write = net.WriteMatrix,
	read = net.ReadMatrix
})
```

Here, we create a new "matrix" *Structure Type*. *Structure Type*s contain a name for pretty-printing, a predicate to decide if a given variable maps to the type, and read and write functions for networking.

Custom `Structure Type`s can be used in-place of `STRUCTURE_*` enums, having `write` called when the type is sent and `read` called when the type is read.
```
net.RegisterStructure("my_struct", {
	name = STRUCTURE_STRING,
	items = {"matrix"} -- denotes that `items` is a sequential array of the "matrix" Structure Type
})

if (SERVER) then
	util.AddNetworkString("my_struct_nws")
	util.AddNetworkString("my_struct_nws_tbl")
	
	function netStructureTest(ply)
		net.Start("my_struct_nws")
			net.WriteStructure("my_struct", {
				name = "Gambit",
				items = {
					Matrix({{0, 0, 0, 0}, {1, 1, 1, 1}, {2, 2, 2, 2}, {3, 3, 3, 3}}),
					Matrix({{0, 1, 2, 3}, {4, 5, 6, 7}, {8, 9, 8, 7}, {6, 5, 4, 2}})
				}
			})
		net.Send(ply)
		
		net.Start("my_struct_nws_tbl")
			net.WriteTable({
				name = "Gambit",
				items = {
					Matrix({{0, 0, 0, 0}, {1, 1, 1, 1}, {2, 2, 2, 2}, {3, 3, 3, 3}}),
					Matrix({{0, 1, 2, 3}, {4, 5, 6, 7}, {8, 9, 8, 7}, {6, 5, 4, 2}})
				}
			})
		net.Send(ply)
	end
else
	net.Receive("my_struct_nws", function(l)
		print("net.ReadStructure", l)
		PrintTable(net.ReadStructure("my_struct"))
	end)
	
	net.Receive("my_struct_nws_tbl", function(l)
		print("net.ReadTable", l)
		PrintTable(net.ReadTable())
	end)
end
```