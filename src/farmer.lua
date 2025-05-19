CROP_INFO = {
  ["minecraft:carrots"] = { ["max_growth"] = 7, ["seed_item"] = "minecraft:carrot" },
  ["minecraft:wheat"] = { ["max_growth"] = 7, ["seed_item"] = "minecraft:wheat_seeds" },
  ["minecraft:potatoes"] = { ["max_growth"] = 7, ["seed_item"] = "minecraft:potato" },
}
-- how many extra fuel to save before returning
FUEL_BUFFER = 2
-- how many fuel items to keep in inventory
FUEL_COUNT = 8
--slot to store the fuel
FUEL_SLOT = 1
-- time between harvests ~10 mins seems a good time for crops to grow
SLEEP_TIME = 10 * 60

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

-- face positive x if at 0,0
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

-- dump the inventory of the turtle (excepting fuel)
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

-- find the home corner in the farm, identified by a glass above and orient self
function goHome()
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

-- inspect the block below, mine it and replace with the related seed item
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
  if data.metadata ~= crop.max_growth then
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

function incTurn(turn, inc)
  local sum = turn + inc
  if sum == 4 then
    return 0
  elseif sum == -1 then
    return 3
  end
  return sum
end

-- main work loop
function harvestLoop()
  -- go home at start
  goHome()

  -- rows are the axis inline with the fuel chest denote as x
  local row = 0
  -- colrs are the axis inline with the dump chest denote as y
  local col = 0

  -- 0 is facing away from fuel chest,
  -- 1 is to the right,
  -- 2 towards chest,
  -- 3 to the left
  local orient = 0

  while true do
    local success, _ = turtle.inspect()

    if success then
      -- we've touched a block, assume its the edge of the farm
      -- harvest before turning, unlikely edge here that inv is full
      harvest()
      local blocked = false
      if row % 2 == 0 then
        turtle.turnRight()
        orient = incTurn(orient, 1)
        blocked, _ = turtle.inspect()
        if blocked then
          break
        end

        turtle.forward()
        row = row + 1
        turtle.turnRight()
        orient = incTurn(orient, 1)
      else
        turtle.turnLeft()
        orient = incTurn(orient, -1)

        blocked, _ = turtle.inspect()
        if blocked then
          break
        end

        turtle.forward()
        row = row + 1
        turtle.turnLeft()
        orient = incTurn(orient, -1)
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

    turtle.forward()
    if row % 2 == 0 then
      col = col + 1
    else
      col = col - 1
    end
  end
  -- broke out of harvest loop, must have hit the ending wall when turning

  goHome()
  dumpInventory(false)
  restockFuel(true)
end

function main()
  while true do
    harvestLoop()
    sleep(SLEEP_TIME)
  end
end

main()
