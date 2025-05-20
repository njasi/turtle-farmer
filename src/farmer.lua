-- information on the crops that might be in the farm
CROP_INFO = {
  ["minecraft:carrots"] = { ["max_growth"] = 7, ["seed_item"] = "minecraft:carrot" },
  ["minecraft:wheat"] = { ["max_growth"] = 7, ["seed_item"] = "minecraft:wheat_seeds" },
  ["minecraft:potatoes"] = { ["max_growth"] = 7, ["seed_item"] = "minecraft:potato" },
  ["minecraft:beetroots"] = { ["max_growth"] = 3, ["seed_item"] = "minecraft:beetroot_seeds" },
  ["minecraft:pumpkin"] = { ["max_growth"] = 0, ["seed_item"] = nil },
  ["minecraft:melon_block"] = { ["max_growth"] = nil, ["seed_item"] = nil },
  ["minecraft:cactus"] = { ["max_growth"] = nil, ["seed_item"] = nil, ["max_height"] = 3, ["shy"] = true },
  ["minecraft:reeds"] = { ["max_growth"] = nil, ["seed_item"] = nil, ["max_height"] = 3 },
}
-- how many extra fuel to save before returning
FUEL_BUFFER = 2
-- how many fuel items to keep in inventory
FUEL_COUNT = 8
--slot to store the fuel
FUEL_SLOT = 1
-- time between harvests ~10 mins seems a good time for crops to grow idk
SLEEP_TIME = 10 * 60

-- look for item in inventory
function findItem(name)
  for i = 2, 16 do
    turtle.select(i)
    local item = turtle.getItemDetail()
    if item ~= nil and item.name == name then
      return i
    end
  end
  return -1
end

-- check if inventory is full, ie no empty slots
function isInventoryFull()
  for i = 2, 16 do
    turtle.select(i)
    local count = turtle.getItemCount()
    if count == 0 then
      return false
    end
  end
  return true
end

-- dump the inventory of the turtle (excepting fuelslot)
-- assume the turtle is at 0,0
function dumpInventory(facingZero)
  if not facingZero then
    orientZero()
  end
  turtle.turnRight()
  turtle.turnRight()
  for i = 2, 16 do
    turtle.select(i)
    turtle.drop()
  end
  turtle.turnRight()
  turtle.turnRight()
end

-- restock the turtle's fuel, assume at 0,0
-- dont get more fuel if we have more than FUEL_COUNT
function restockFuel(facingZero)
  turtle.select(FUEL_SLOT)
  local count = turtle.getItemCount()
  if count >= FUEL_COUNT then
    return
  end

  if not facingZero then
    orientZero()
  end
  turtle.turnLeft()
  turtle.suck(FUEL_COUNT - count)
  turtle.turnRight()
end

-- goto a position relative to the home
function goToPosition(tx, ty, to, cx, cy, co)
  if cx == tx and cy == ty then
    return
  end

  local orient = co
  if cx > tx then
    -- need go in -x
    orient = orientTurtle(orient, 3)
  elseif cx < tx then
    -- need go in +x, orient->
    orient = orientTurtle(orient, 1)
  end

  for _ = 1, math.abs(cx - tx) do
    turtle.forward()
  end


  if cy > ty then
    -- need go in -y
    orient = orientTurtle(orient, 2)
  elseif cy < ty then
    -- need go in +y, orient->
    orient = orientTurtle(orient, 0)
  end

  for _ = 1, math.abs(cy - ty) do
    turtle.forward()
  end

  orientTurtle(orient, to)
end

-- find the home corner in the farm,
-- identified by a glass above. then orient self
function findHome()
  while true do
    local success, data = turtle.inspectUp()
    if success and data.name == "minecraft:glass" then
      -- orient self towards an air block
      orientZero()
      break
    end

    success, _ = turtle.inspect()
    if success then
      turtle.turnRight()
    end
    turtle.forward()
  end
end

-- face positive x iff at 0,0
function orientZero()
  -- first we rotate until we see block
  while true do
    success, _ = turtle.inspect()
    if success then
      break
    end
    turtle.turnRight()
  end

  -- then rotate until we see air
  while true do
    success, _ = turtle.inspect()
    if not success then
      break
    end
    turtle.turnRight()
  end
end

-- turn a turtle to match desired orientation
function orientTurtle(current, target)
  if current == target then
    return target
  elseif current > target then
    for _ = 1, current - target do
      turtle.turnLeft()
    end
  elseif current < target then
    for _ = 1, target - current do
      turtle.turnRight()
    end
  end
  return target
end

-- incrementally turn keeping track of orientation
function incTurn(turn, inc)
  local sum = turn + inc
  if sum == 4 then
    return 0
  elseif sum == -1 then
    return 3
  end
  return sum
end

-- inspect the block below, mine it and replace with the
-- related seed item if applicable

function harvest()
  success, data = turtle.inspectDown()

  -- TODO define some default behavior here
  if not success then
    return false
  end

  -- lookup crop info, break if ready
  local crop = CROP_INFO[data.name]
  if crop == nil then
    -- crop not in table, define default behavior
    return false
  end
  -- crop not grown / skip if max_growth is nil
  if crop.max_growth ~= nil and data.metadata ~= crop.max_growth then
    return false
  end

  turtle.select(FUEL_SLOT)
  turtle.digDown()
  if findItem(crop.seed_item) == -1 then
    -- default behavior if out of seeds of this type?
    return false
  else
    turtle.placeDown()
  end

  return true
end

-- harvest a tall crop if we run into one
function harvestTall(crop)
  -- go up
  for _ = 1, crop.max_height - 2 do
    turtle.up()
  end

  -- go down and harvest 1 by 1
  for _ = 1, crop.max_height - 2 do
    turtle.dig()
    turtle.down()
  end
end

-- turn around when reaching an end of the farm
-- return 2 tuple
-- true if success/false if blocked, orient
function handleTurn(orient, row)
  if row % 2 == 0 then
    turtle.turnRight()
    orient = incTurn(orient, 1)
    local f = turtle.forward()

    if not f then
      return false, orient
    end

    turtle.turnRight()
    orient = incTurn(orient, 1)
  else
    turtle.turnLeft()
    orient = incTurn(orient, -1)

    local f = turtle.forward()
    if not f then
      return false, orient
    end

    turtle.turnLeft()
    orient = incTurn(orient, -1)
  end
  return true, orient, nil
end

-- main harvesting loop
function harvestLoop()
  -- go home at start
  findHome()

  -- rows are the axis inline with the fuel chest denote as x
  local row = 0
  -- cols are the axis inline with the dump chest denote as y
  local col = 0

  -- 0 is facing away from fuel chest,
  -- 1 is to the right,
  -- 2 towards chest,
  -- 3 to the left
  local orient = 0

  local forward = true

  while true do
    if not forward then
      -- we've touched a block, assume its the edge of the farm
      -- harvest before turning, unlikely edge case here that inv is full
      harvest()
      local _, data = turtle.inspect()
      local crop = CROP_INFO[data.name]

      if crop ~= nil and crop.max_height ~= nil then
        -- if we've just run into a tall crop harvest it
        harvestTall(crop)
      else
        -- otherwise we try turning
        local success, o = handleTurn()
        orient = o
        row = row + 1
        if not success then
          -- not gonna verify block is there since
          -- we just ran into it
          local _, data = turtle.inspect()
          local crop = CROP_INFO[data.name]

          -- if the thing that stopped our turn was a crop
          -- then harvest it and resume turning
          if crop ~= nil and crop.max_height ~= nil then
            harvestTall(crop)
            if row % 2 == 0 then
              turtle.turnLeft()
              orient = incTurn(orient, -1)
            else
              turtle.turnRight()
              orient = incTurn(orient, 1)
            end
          else
            -- else we ran into a wall and should break
            break
          end
        end
      end
    end
    local checkInventory = harvest()

    local needsFuel = false
    if turtle.getFuelLevel() < row + col + FUEL_BUFFER then
      turtle.select(FUEL_SLOT)
      if turtle.getItemCount() == 0 then
        needsFuel = true
      else
        turtle.refuel(1)
      end
    end

    -- return whenever fuel is needed or inventory is full
    if (checkInventory and isInventoryFull()) or needsFuel then
      goToPosition(0, 0, 0, row, col, orient)
      dumpInventory(true)
      restockFuel(true)
      goToPosition(row, col, orient, 0, 0, 0)
    end

    forward = turtle.forward()
    if row % 2 == 0 then
      col = col + 1
    else
      col = col - 1
    end
  end
  -- broke out of harvest loop, must have hit the ending wall when turning

  findHome()
  dumpInventory(false)
  restockFuel(true)
end

-- main loop of harvesting loops lol
function main()
  while true do
    harvestLoop()
    sleep(SLEEP_TIME)
  end
end

main()
