function pos_add(pos1, pos2)
  return {
    x=pos1.x + pos2.x,
    y=pos1.y + pos2.y
  }
end

function pos_sub(pos1, pos2)
  return {
    x=pos1.x - pos2.x,
    y=pos1.y - pos2.y
  }
end

function pos_dup(pos1)
  return {
    x=pos1.x,
    y=pos1.y,
  }
end

function pos_rot(pos, direction)
  if direction == 0 then
    return pos_dup(pos)
  elseif direction == 6 then
    return {x=-pos.y,y=pos.x}
  elseif direction == 4 then
    return {x=-pos.x,y=-pos.y}
  elseif direction == 2 then
    return {x=pos.y,y=-pos.x}
  end
end

function transform_blueprint_position(delta, direction, position, blueprint_center)
  local relative_position = pos_sub(position, blueprint_center)
  return pos_add(delta, pos_add(blueprint_center, pos_rot(relative_position, direction)))
end

function transform_aabb(delta, direction, xmin, xmax, ymin, ymax, blueprint_center)
  if direction == 0 or direction == 4 then
    return xmin + delta.x, xmax + delta.x, ymin + delta.y, ymax + delta.y
  elseif direction == 2 or direction == 6 then
    local xdiff = blueprint_center.x - xmin
    local ydiff = blueprint_center.y - ymin
    return blueprint_center.x - ydiff + delta.x, blueprint_center.x + ydiff + delta.x, blueprint_center.y - xdiff + delta.y, blueprint_center.y + xdiff + delta.y
  end
end

function turn_belts(surface, area, direction1, direction2, flag)
  local icount = 1
  for i=area.left_top.x,area.right_bottom.x do
    local jcount = 1
    for j=area.left_top.y,area.right_bottom.y do
      local belts = surface.find_entities_filtered{type="transport-belt", position={x=i+0.5,y=j+0.5}}
      if belts[1] then
        if jcount <= icount + (flag and 0 or -1) then
          belts[1].direction = direction1
        else
          belts[1].direction = direction2
        end
      else
        local belt_ghosts = surface.find_entities_filtered{position={x=i+0.5,y=j+0.5}, ghost_type="transport-belt"}
        if belt_ghosts[1] then
          if jcount <= icount + (flag and 0 or -1) then
            belt_ghosts[1].direction = direction1
          else
            belt_ghosts[1].direction = direction2
          end
        end
      end
      jcount = jcount + 1
    end
    icount = icount + 1
  end
end

function turn_belts2(surface, area, direction1, direction2, flag)
  local icount = 1
  for i=area.left_top.x,area.right_bottom.x do
    local jcount = 1
    for j=area.left_top.y,area.right_bottom.y do
      local belts = surface.find_entities_filtered{type="transport-belt", position={x=i+0.5,y=j+0.5}}
      if belts[1] then
        if jcount + icount <= area.right_bottom.x - area.left_top.x + (flag and 1 or 2) then
          belts[1].direction = direction1
        else
          belts[1].direction = direction2
        end
      else
        local belt_ghosts = surface.find_entities_filtered{position={x=i+0.5,y=j+0.5}, ghost_type="transport-belt"}
        if belt_ghosts[1] then
          if jcount + icount <= area.right_bottom.x - area.left_top.x + (flag and 1 or 2) then
            belt_ghosts[1].direction = direction1
          else
            belt_ghosts[1].direction = direction2
          end
        end
      end
      jcount = jcount + 1
    end
    icount = icount + 1
  end
end

function compute_direction_array_2(surface, area)
  local array = {}
  -- store the directions of belt ghosts
  local ghost_belts = surface.find_entities_filtered{area=area, ghost_type="transport-belt"}
  for _, ghost_belt in pairs(ghost_belts) do
    array[math.floor(ghost_belt.position.x)] = array[math.floor(ghost_belt.position.x)] or {}
    array[math.floor(ghost_belt.position.x)][math.floor(ghost_belt.position.y)] = ghost_belt.direction or 0
  end
  -- store the directions of belts
  local belts = surface.find_entities_filtered{area=area, type="transport-belt"}
  for _, belt in pairs(belts) do
    array[math.floor(belt.position.x)] = array[math.floor(belt.position.x)] or {}
    array[math.floor(belt.position.x)][math.floor(belt.position.y)] = belt.direction or 0
  end
  -- any position not filled by a belt direction gets a direction of -1 (not 0 because belt directions are 0, 2, 4, 6)
  for i=area.left_top.x,area.right_bottom.x do
    -- local debug_string = ""
    array[i] = array[i] or {}
    for j=area.left_top.y,area.right_bottom.y do
      array[i][j] = array[i][j] or -1
      -- if array[i][j] >= 0 then
      --   debug_string = debug_string..tostring(array[i][j]).." "
      -- else
      --   debug_string = debug_string.."X "
      -- end
    end
    -- game.print(debug_string)
  end
  return array
end

function on_pre_build(event)
  local player = game.players[event.player_index]
  if not (player.cursor_stack and player.cursor_stack.valid and player.cursor_stack.valid_for_read and player.cursor_stack.is_blueprint and player.cursor_stack.is_blueprint_setup()) then return end

  -- maybe check the players cursor for a blueprint of transport belt lines, then check the pasted location for a set of belts of equal size for a corner
  -- but again, there will be no belts for the on_pre_build event, we will get separate events for all of the ghosts
  -- all of the events for the ghosts will come in on the same tick so we can delay a tick before correcting the orientation of the other belts in order to "batch" the pasted ghosts
  -- when the on_built_entity events come in for the belts, we should build a rectangle of the belts that were pasted, then find the orientation of the rectangle based on the belts, and then check the NxN square on both ends for a turn
  -- where N is the width of the multi-belt
  -- better idea would be to wait for belts being built and we can exclusively listen for that event

  local cursor_position = global.cursor_positions[event.player_index]
  if not cursor_position then return end

  -- game.print("pre_build "..serpent.block(cursor_position))
  -- so next step would be to transform the AABB using the direction and flipped information to find the positions for which it overlaps with existing belts, and then transform the directions of the belts in the AABB as well
  -- to compute the belts that need to be turned

  -- for now let's assume the blueprint is only belts in the same direction
  -- compute aabb
  local blueprint = player.cursor_stack
  local xmin, xmax, ymin, ymax
  for _, blueprint_entity in pairs(blueprint.get_blueprint_entities()) do
    if not (xmin and xmax and ymin and ymax) then 
      xmin = blueprint_entity.position.x
      xmax = blueprint_entity.position.x
      ymin = blueprint_entity.position.y
      ymax = blueprint_entity.position.y
    end

    if blueprint_entity.position.x < xmin then xmin = blueprint_entity.position.x end
    if blueprint_entity.position.x > xmax then xmax = blueprint_entity.position.x end
    if blueprint_entity.position.y < ymin then ymin = blueprint_entity.position.y end
    if blueprint_entity.position.y > ymax then ymax = blueprint_entity.position.y end
  end

  -- store aabb center
  local blueprint_center = {
    x=(xmin + xmax) / 2,
    y=(ymin + ymax) / 2,
  }
  local delta = {
    x=cursor_position.x - blueprint_center.x,
    y=cursor_position.y - blueprint_center.y
  }
  local blueprint_direction = nil
  for _, blueprint_entity in pairs(blueprint.get_blueprint_entities()) do
    local real_direction = blueprint_entity.direction or 0
    if not blueprint_direction then
      blueprint_direction = real_direction
    end
    if blueprint_direction ~= real_direction then game.print("blueprint direction did not match") return end
  end
  -- game.print("blueprint count"..blueprint.get_blueprint_entity_count())
  local brush_width = math.min(ymax - ymin, xmax - xmin) + 1
  -- if brush_width < 2 then game.print("brush width "..tostring(brush_width).. " too small") return end

  -- somehow I now detect and turn belts
  -- ok better idea lol
  -- just find the square that is the overlap
  -- I only want a square thats on the edge of the blueprint AABB
  -- so I could do that finding squares algorithm
  -- or the easier way to deal with it is to check from the top/bottom of the blueprint AABB
  -- but I find the square, then find the belts to the sides. I know the direction of the belts in the blueprint so I know which two sides to check
  -- since I never want to check the belt on the same parallel direction side of the square

  -- but this is finishable
  -- so I have two potential squares to check on the blueprint since I will guarantee it's a rectangle
  local t_xmin, t_xmax, t_ymin, t_ymax = transform_aabb(delta, event.direction, xmin, xmax, ymin, ymax, blueprint_center)
  local area = {left_top={x=math.floor(t_xmin),y=math.floor(t_ymin)}, right_bottom={x=math.floor(t_xmax)+1,y=math.floor(t_ymax)+1}}
  local surface = player.surface
  local array = compute_direction_array_2(surface, area)

  local candidate_square = find_square(array, area)
  -- game.print(serpent.block(candidate_square))
  if not candidate_square or candidate_square.size ~= brush_width then game.print("no square of width == " .. tostring(brush_width)) return end

  -- game.print("found square overlap of "..serpent.block(candidate_square))

  -- replace the orientation of the belts in the square overlap to make them connect
  local square_direction = nil
  for i=candidate_square.x-candidate_square.size+1,candidate_square.x do
    for j=candidate_square.y-candidate_square.size+1,candidate_square.y do
      if not square_direction then
        square_direction = array[i][j]
      end
      if square_direction ~= array[i][j] then game.print("square direction did not match") return end 
    end
  end

  blueprint_direction = (blueprint_direction + event.direction) % 8
  -- game.print("existing direction " .. tostring(square_direction))
  -- game.print("blueprint direction " .. tostring(blueprint_direction))

  if blueprint_direction == square_direction or (blueprint_direction + 4) % 8 == square_direction then
    game.print("directions not at 90 degree angle")
    return
  end

  -- compute the direction in each of the 4 sides of the square
  -- determine which directions match those of the blueprint paste and the existing belts
  -- then from those we can have a lookup table of which of the chiral options for the belt corner it needs
  -- then we set directions based on a rotation of that chiral option
  -- ok so if I compute the belt direction in and the belt direction out, I can lookup table which belts need to be turned, since
  -- I'm too tired to figure out the code for each individually (maybe lookup table of functions I guess)

  -- for checking the sides of the square we want to check a square with 1 additional row/column on each side of the original square
  -- which could be accomplished by taking the original square and expanding it by 1 but taking the blueprint rectangle and expanding it
  -- by 1 will contain this desired square while still containing all blueprint entity positions
  local area_extension = {left_top={x=area.left_top.x-1,y=area.left_top.y-1}, right_bottom={x=area.right_bottom.x+1,y=area.right_bottom.y+1}}
  local array_extension = compute_direction_array_2(surface, area_extension)
  for _, blueprint_entity in pairs(blueprint.get_blueprint_entities()) do
    local xformed_pos = transform_blueprint_position(delta, event.direction, blueprint_entity.position, blueprint_center)
    local xformed_x = math.floor(xformed_pos.x)
    local xformed_y = math.floor(xformed_pos.y)
    if array_extension[xformed_x][xformed_y] < 0 then
      array_extension[xformed_x] = array_extension[xformed_x] or {}
      array_extension[xformed_x][xformed_y] = ((blueprint_entity.direction or 0 ) + event.direction) % 8
    end
  end

  x_left = {left_top={x=candidate_square.x+1,y=candidate_square.y-candidate_square.size+1}, right_bottom={x=candidate_square.x+1,y=candidate_square.y}}
  x_right = {left_top={x=candidate_square.x-candidate_square.size,y=candidate_square.y-candidate_square.size+1}, right_bottom={x=candidate_square.x-candidate_square.size,y=candidate_square.y}}
  y_top = {left_top={x=candidate_square.x-candidate_square.size+1,y=candidate_square.y+1}, right_bottom={x=candidate_square.x,y=candidate_square.y+1}}
  y_bottom = {left_top={x=candidate_square.x-candidate_square.size+1,y=candidate_square.y-candidate_square.size}, right_bottom={x=candidate_square.x,y=candidate_square.y-candidate_square.size}}
  x_left_dir = compute_area_direction(array_extension, x_left)
  x_right_dir = compute_area_direction(array_extension, x_right)
  y_top_dir = compute_area_direction(array_extension, y_top)
  y_bottom_dir = compute_area_direction(array_extension, y_bottom)
  -- game.print("x_left"..tostring(x_left_dir).." x_right"..tostring(x_right_dir).." y_top_dir"..tostring(y_top_dir).. "y_bottom_dir"..tostring(y_bottom_dir))

  local area_turn={left_top={x=candidate_square.x-brush_width+1,y=candidate_square.y-brush_width+1}, right_bottom={x=candidate_square.x,y=candidate_square.y}}
  if x_right_dir == 2 and y_bottom_dir == 0 then
    turn_belts(surface, area_turn, 0, 2, true)
  elseif x_left_dir == 2 and y_top_dir == 0 then
    turn_belts(surface, area_turn, 2, 0, true)
  elseif (x_right_dir == 2 and y_top_dir == 4) then
    turn_belts2(surface, area_turn, 2, 4, true)
  elseif (x_left_dir == 2 and y_bottom_dir == 4) then
    turn_belts2(surface, area_turn, 4, 2, true)
  elseif (x_right_dir == 6 and y_top_dir == 0) then
    turn_belts2(surface, area_turn, 6, 0, false)
  elseif (x_left_dir == 6 and y_bottom_dir == 0) then
    turn_belts2(surface, area_turn, 0, 6, false)
  elseif (x_right_dir == 6 and y_bottom_dir == 4) then
    turn_belts(surface, area_turn, 4, 6, false)
  elseif (x_left_dir == 6 and y_top_dir == 4) then
    turn_belts(surface, area_turn, 6, 4, false)
  end
end
script.on_event(defines.events.on_pre_build, on_pre_build)

-- function on_built_entity(event)
--   local player = game.players[event.player_index]
--   local entity = event.created_entity
--   local position = {x=math.floor(entity.position.x), y=math.floor(entity.position.y)}
--   local area = area_from_position(position, 9)
--   local array = compute_direction_array(player.surface, area, position)
--   -- find a candidate belt square for turning
--   local candidate_square = find_square(array, area)
--   if not candidate_square then return end
--   game.print(serpent.block(candidate_square))
--   -- validate the square and compute the direction of the incoming and outgoing lines
--   local x_dir, y_dir = validate_and_compute_directions(array, candidate_square)
--   -- the belt box for the x and y directions need to have the same direction for all belts in them
--   if not (x_dir and y_dir) then return end

-- end
-- script.on_event(defines.events.on_built_entity, on_built_entity)

-- function on_init(event)
--   -- table to tracking the ghosts built on this tick by each player
--   global.belt_ghosts = {}
-- end
-- script.on_init(on_init)

-- is there some way to keep track of the belt turns that would play nicely with ctrl+Z for undo since if I placed a blueprint and didn't want it, I wouldn't want to have to *unturn* all the belts
-- If I tracked every tick whether the player took an undoable action, then I could have the order to know ehther ctrl+Z should undo or not

-- the best way to do this would be each time a belt ghost is placed, look for a NXN section of belts "near" it that has N belts going into it on one side, and N belts going out of it on a 90 degree turned side, and no belts on the other side
-- doing that for every belt would work but isn't ideal since that'd be more work than necessary
-- but it'd be trivial to do the batching afterwards

-- so let's write a function that takes a rectangle of belt ghosts, and configures things correctly
-- assumptions
-- belt ghosts all point the same direction
-- from the direction we can find the ends of the aabb that need to be checked
function area_from_position(position, radius)
  return {left_top = {x = position.x - radius, y = position.y - radius}, right_bottom = {x = position.x + radius, y = position.y + radius}}
end

local directions = {{x=1,y=0},{x=-1,y=0},{x=0,y=1},{x=0,y=-1}}

function compute_direction_array(surface, area, position)
  local count = 0
  local array = {}
  -- store the directions of belt ghosts
  local ghost_belts = surface.find_entities_filtered{area=area, ghost_type="transport-belt"}
  for _, ghost_belt in pairs(ghost_belts) do
    array[math.floor(ghost_belt.position.x)] = array[math.floor(ghost_belt.position.x)] or {}
    array[math.floor(ghost_belt.position.x)][math.floor(ghost_belt.position.y)] = ghost_belt.direction
    count = count + 1
  end
  -- store the directions of belts
  local belts = surface.find_entities_filtered{area=area, type="transport-belt"}
  for _, belt in pairs(belts) do
    array[math.floor(belt.position.x)] = array[math.floor(belt.position.x)] or {}
    array[math.floor(belt.position.x)][math.floor(belt.position.y)] = belt.direction
  end
  -- any position not filled by a belt direction gets a direction of -1 (not 0 because belt directions are 0, 2, 4, 6)
  for i=area.left_top.x,area.right_bottom.x do
    -- local debug_string = ""
    array[i] = array[i] or {}
    for j=area.left_top.y,area.right_bottom.y do
      array[i][j] = array[i][j] or -1
      -- if array[i][j] >= 0 then
      --   debug_string = debug_string..tostring(array[i][j]).." "
      -- else
      --   debug_string = debug_string.."X "
      -- end
    end
    -- game.print(debug_string)
  end

  -- determine all positions that are contiguous with the passed position
  local valid_positions = {}
  local position_stack = {}
  table.insert(position_stack, position)
  local stack_size = 1
  while stack_size > 0 do
    -- remove the top of the stack and mark it valid
    local curr_position = table.remove(position_stack)
    stack_size = stack_size - 1
    valid_positions[curr_position.x] = valid_positions[curr_position.x] or {}
    valid_positions[curr_position.x][curr_position.y] = true
    -- check all directions from the position being examined
    for _, dir in pairs(directions) do
      local x_mod = curr_position.x + dir.x
      local y_mod = curr_position.y + dir.y
      valid_positions[x_mod] = valid_positions[x_mod] or {}
      valid_positions[x_mod][y_mod] = valid_positions[x_mod][y_mod] or false
      -- if the checked position is not valid but has a belt direction, add it to the stack
      if not valid_positions[x_mod][y_mod] and array[x_mod] and array[x_mod][y_mod] and array[x_mod][y_mod] >= 0 then
        table.insert(position_stack,{x=x_mod,y=y_mod})
        stack_size = stack_size + 1
      end
    end
  end

  -- mask the direction array based on the valid_positions
  for i=area.left_top.x,area.right_bottom.x do
    -- local debug_string = ""
    for j=area.left_top.y,area.right_bottom.y do
      valid_positions[i] = valid_positions[i] or {}
      if not valid_positions[i][j] then
        array[i][j] = -1
      end
      -- if array[i][j] >= 0 then
      --   debug_string = debug_string..tostring(array[i][j]).." "
      -- else
      --   debug_string = debug_string.."X "
      -- end
    end
    -- game.print(debug_string)
  end

  return array
end

function find_square(array, area)
  local square_size = {}
  -- additional 1 row/col to the top_left to not have to do out-of-bounds checks
  for i=area.left_top.x-1,area.right_bottom.x do
    square_size[i] = square_size[i] or {}
    for j=area.left_top.y-1,area.right_bottom.y do
      square_size[i][j] = square_size[i][j] or 0
    end
  end

  --  compute the size of the square to the top_left of each cell
  local max_size = -1
  -- game.print("area "..serpent.block(area))
  for i=area.left_top.x,area.right_bottom.x do
    -- local debug_string = ""
    for j=area.left_top.y,area.right_bottom.y do
      if array[i][j] >= 0 then
        square_size[i][j] = math.min(square_size[i-1][j-1], square_size[i-1][j], square_size[i][j-1]) + 1
        if square_size[i][j] > max_size then
          max_size = square_size[i][j]
        end
      end
      -- debug_string = debug_string..tostring(square_size[i][j])
    end
    -- game.print(debug_string)
  end

  -- no square was found at all so return early
  if max_size == -1 then game.print("size -1") return end

  -- mask the square_size to only look at the maximal squares
  for i=area.left_top.x,area.right_bottom.x do
    -- local debug_string = ""
    for j=area.left_top.y,area.right_bottom.y do
      if square_size[i][j] < max_size then
        square_size[i][j] = 0
      end
      -- debug_string = debug_string..tostring(square_size[i][j])
    end
    -- game.print(debug_string)
  end

  for i=area.left_top.x,area.right_bottom.x do
    for j=area.left_top.y,area.right_bottom.y do
      if square_size[i][j] > 0 then return {x=i,y=j,size=max_size} end
    end
  end
end


function is_empty(array, area)

end

-- compute this from the computed direction array since they must have been present
function compute_area_direction(array_extension, area)
  local direction = nil
  for i=area.left_top.x,area.right_bottom.x do
    for j=area.left_top.y,area.right_bottom.y do
      local belt_direction = nil
      if array_extension[i] and array_extension[i][j] then
        belt_direction = array_extension[i][j]
      end
      if not direction then
        direction = belt_direction
      end
      if direction ~= belt_direction then return nil end
    end
  end
  return direction
end

-- function validate_and_compute_directions(array, square)
--   -- the position of the square is given by the top_left so we have to compute the edges from that position
--   local x_belt_box = nil
--   local x_not_belt_box = nil
--   if square.x_dir == 1 then
--     x_belt_box = {left_top={x=square.x+1,y=square.y}, right_bottom={x=square.x+1,y=square.y-square.size+1}}
--     x_not_belt_box = {left_top={x=square.x-square.size,y=square.y}, right_bottom={x=square.x-square.size,y=square.y-square.size+1}}
--     game.print(serpent.block(x_belt_box))
--   elseif square.x_dir == -1 then
--     x_belt_box = {left_top={x=square.x-square.size,y=square.y}, right_bottom={x=square.x-square.size,y=square.y-square.size+1}}
--     x_not_belt_box = {left_top={x=square.x+1,y=square.y}, right_bottom={x=square.x+1,y=square.y-square.size+1}}
--     game.print(serpent.block(x_belt_box))
--   end
--   local y_belt_box = nil
--   local y_not_belt_box = nil
--   if square.y_dir == 1 then
--     y_belt_box = {left_top={x=square.x,y=square.y+1}, right_bottom={x=square.x-square.size+1,y=square.y+1}}
--     y_not_belt_box = {left_top={x=square.x,y=square.y-square.size}, right_bottom={x=square.x-square.size+1,y=square.y-square.size}}
--     game.print(serpent.block(y_belt_box))
--   elseif square.y_dir == -1 then
--     y_belt_box = {left_top={x=square.x,y=square.y-square.size}, right_bottom={x=square.x-square.size+1,y=square.y-square.size}}
--     y_not_belt_box = {left_top={x=square.x,y=square.y+1}, right_bottom={x=square.x-square.size+1,y=square.y+1}}
--     game.print(serpent.block(y_belt_box))
--   end
--   if not (x_belt_box and y_belt_box) then return nil, nil end

--   -- verify that the opposite belt boxes are empty
--   x_is_empty = is_empty(array, x_not_belt_box)
--   y_is_empty = is_empty(array, y_not_belt_box)
--   if not (x_is_empty and y_is_empty) then return nil, nil end

--   return compute_belt_box_direction(array, x_belt_box), compute_belt_box_direction(array, y_belt_box)
-- end

-- supporting dragging blueprints is a headache
-- or at least I'm having trouble seeing how it should work

-- since essentially on the tick we finally get a valid belt turning setup, we might have just placed a *single* belt
-- so we actually do have to go with the idea of detecting it based off just a single belt position
-- the final belt placement that makes a belt turn valid is either going to be a part of the corner, or one of the lines entering/exiting the corner
-- so we need to find a corner from there
-- but finding a corner is not trivial
-- why is this so complicated
-- it's still essentially just a flood fill of only "transport-belt" from the position. probably we get all the belts in some box around the final position based on some maximum for the mod setting
-- then flood fill from those, and then we have a 2d grid of transport-belt presence/orientation (-1 doesnt exist, 0, 2, 4, 8 for orientations)
-- then some algorithm finds the largest square of belts in there
-- it's a fucking leetcode problem https://leetcode.com/problems/maximal-square/ fml
-- well at that least it gives me a linear time algorithm for finding the square
-- then we check the edges of the square

-- I'll be running this for each belt, which still sounds terrible. can I minimize it to once per tick (yes if I do batching but do that later)

function on_belt_turner(event)
  local player = game.players[event.player_index]
  if not (player.cursor_stack and player.cursor_stack.valid and player.cursor_stack.valid_for_read and player.cursor_stack.is_blueprint and player.cursor_stack.is_blueprint_setup()) then return end
  -- game.print(serpent.block(event.cursor_position))
  global.cursor_positions = global.cursor_positions or {}
  global.cursor_positions[event.player_index] = event.cursor_position
end
script.on_event("belt-turner", on_belt_turner)

function on_tick(event)
  -- clear the cursor position every tick since we only using during a single tick
  -- to pass information from the custom input event to the pre build event
  global.cursor_positions = {}
end
script.on_nth_tick(1, on_tick)