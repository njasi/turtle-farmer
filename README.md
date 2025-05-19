# Farmer tm
Simple farming script for computercraft turtles

## Features
- Will plant the same crop as was harvested from a position, allowing for rows or other patterns in your crops.
- [Configurable](#crops) for any 1 tall crop.
- Farm can be of any (rectangular) size.
- Turtle auto homes on startup from any position.

## Setup
This itself script is quite simple to use but it does require some specific farm setup.

### Turtle
As usual we can setup the script with pastebin:
```sh
pastebin get [PASTEBIN_ID] farmer.lua
```
Otherwise the turtle needs a pickaxe equiped.

### Farm
We have a list of requirements for how your farm is made below. Let the home position be any corner of your farm.

- The farm should be rectangular.
- The farm must be surrounded by 2 high walls (or just a 1 high wall on the same level as the turtle).
- The farm should be fully planted before starting the farmer.
- There should be a glass block above your home position (3 blocks above the dirt of your farm)
- Facing inwards standing at your home:
  - The right wall should be a chest to dump items into
  - The left wall should be a chest to retrieve fuel from
  - Both chests should be 2 blocks above the dirt
- The turtle should be placed directly ontop of the crops, perferrably in the home position.

Example:
![example farm screenshot](./example.png)

### Crops
Crops can be configured in the CROP_INFO global as follows:
```lua
-- information on the crops that might be in the farm
CROP_INFO = {
  ["minecraft:carrots"] = { ["max_growth"] = 7, ["seed_item"] = "minecraft:carrot" },
  ...
}

```
- The key for a specific crop should be its planted block id. (`minecraft:carrots` (planted) vs `minecraft:carrot` (item))
- `max_growth` is the metadata value at which the crop is fully grown.
- `seed_item` is the item id of the item used to plant the crop.


## Compatability
This was made for CC v1.80pr1 and may not function properly in other versions as I have not checked.
