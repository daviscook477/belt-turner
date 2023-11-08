---vector addition
---@param pos1 any
---@param pos2 any
---@return table
function pos_add(pos1, pos2)
  return {
    x=pos1.x + pos2.x,
    y=pos1.y + pos2.y
  }
end

---vector subtract
---@param pos1 any
---@param pos2 any
---@return table
function pos_sub(pos1, pos2)
  return {
    x=pos1.x - pos2.x,
    y=pos1.y - pos2.y
  }
end

---duplicate vector 
---could be replaced with a deepcopy
---@param pos1 any
---@return table
function pos_dup(pos1)
  return {
    x=pos1.x,
    y=pos1.y,
  }
end

---rotate a vector
---only accepts directions 0, 2, 4, 6
---essentially just multiplies the vector by the 2d rotation matrix for the rotation
---represented by the direction (factorio directions are clockwise but typical math notation is counterclockwise so be careful)
---but unrolled and without any sines or cosines
---@param pos any
---@param direction any
---@return table
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

---takes a position within a blueprint defined by its centerpoint and rotates it by the given direction
---also adds the delta onto the final resulting position
---essentially acts as a mapping function from the positions of entities in a blueprint to their positions when pasted with a direction / delta
---@param delta any
---@param direction any
---@param position any
---@param blueprint_center any
---@return table
function transform_blueprint_position(delta, direction, position, blueprint_center)
  local relative_position = pos_sub(position, blueprint_center)
  return pos_add(delta, pos_add(blueprint_center, pos_rot(relative_position, direction)))
end

---performs the same transformation as transform_blueprint_position but on an AABB (axis-aligned bounding box)
---@param delta any
---@param direction any
---@param xmin any
---@param xmax any
---@param ymin any
---@param ymax any
---@param blueprint_center any
---@return unknown
---@return unknown
---@return unknown
---@return unknown
function transform_aabb(delta, direction, xmin, xmax, ymin, ymax, blueprint_center)
  if direction == 0 or direction == 4 then
    -- these directions dont change the positions of the bounds so only modify by the delta
    return xmin + delta.x, xmax + delta.x, ymin + delta.y, ymax + delta.y
  elseif direction == 2 or direction == 6 then
    -- compute the rotation relative to the blueprint center by changing coordinates to blueprint center as (0, 0), rotating, and then reversing the coordinate change
    -- add the delta at the end after the rest of the transformation
    local xdiff = blueprint_center.x - xmin
    local ydiff = blueprint_center.y - ymin
    return blueprint_center.x - ydiff + delta.x, blueprint_center.x + ydiff + delta.x, blueprint_center.y - xdiff + delta.y, blueprint_center.y + xdiff + delta.y
  end
end

--[[
Turning belts has 4 cases represented by the combinations of
1. turn_belts(flag=false)
2. turn_belts(flag=true)
3. turn_belts2(flag=false)
4. turn_belts2(flag=true)
This is because belts turn by having all belts on one side of a diagonal face one direction, and all the belts on the other
side of the diagonal face the other direction. So there are two diagonals, y=x and x+y=size if we consider the square
(0, 0) (size, 0) (0, size) (size, size) so that accounts for turn_belts (y=x) and turn_belts2(x+y=size) but because we
are in the discrete world there are two choices for the position of the cutoff, so the y intercept has to be modified by +0 or +1 for both cases,
making 2 y intercept values by 2 functions is the 4 cases.

1. X X X X
   X X X O
   X X O O
   X O O O
2. X X X O
   X X O O
   X O O O
   O O O O
3. X O O O
   X X O O
   X X X O
   X X X X
4. O O O O
   X O O O
   X X O O
   X X X O

I don't know which of the numbers 1-4 for the function calls actually matches which of the numbers 1-4 for the above cases
but it's not necessary since I set up the function calls through trial-and-error
--]]

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

---create a 2d array that has the direction of transport-belts in every position in the given area
---@param surface any
---@param area any
---@return table
function compute_direction_array(surface, area)
  local array = {}
  -- store the directions of belt ghosts
  local ghost_belts = surface.find_entities_filtered{area=area, ghost_type="transport-belt"}
  for _, ghost_belt in pairs(ghost_belts) do
    local floor_x = math.floor(ghost_belt.position.x)
    local floor_y = math.floor(ghost_belt.position.y)
    array[floor_x] = array[floor_x] or {}
    array[floor_x][floor_y] = ghost_belt.direction or 0 -- the API is weird and returns nil instead of 0
  end
  -- store the directions of belts
  local belts = surface.find_entities_filtered{area=area, type="transport-belt"}
  for _, belt in pairs(belts) do
    local floor_x = math.floor(belt.position.x)
    local floor_y = math.floor(belt.position.y)
    array[floor_x] = array[floor_x] or {}
    array[floor_x][floor_y] = belt.direction or 0 -- the API is weird and returns nil instead of 0
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

---compute the AABB of a given (valid) blueprint
---and verify that the entities within it are all transport belts
---@param blueprint_entities any
---@return number|nil xmin min x value
---@return number|nil xmax max x value
---@return number|nil ymin min y value
---@return number|nil ymax max y value
function compute_blueprint_aabb(blueprint_entities)
  local entity_prototypes = game.entity_prototypes
  local xmin, xmax, ymin, ymax
  for _, blueprint_entity in pairs(blueprint_entities) do
    local entity_prototype = entity_prototypes[blueprint_entity.name]
    if not entity_prototype or entity_prototype.type ~= "transport-belt" then return nil, nil, nil, nil end

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
  return xmin, xmax, ymin, ymax
end

---compute the direction of the blueprint
---@param blueprint_entities any
---@return number|nil direction the direction of the blueprint or nil if the entities in the blueprint do not all match direction
function compute_blueprint_direction(blueprint_entities)
  local blueprint_direction = nil
  for _, blueprint_entity in pairs(blueprint_entities) do
    local real_direction = blueprint_entity.direction or 0 -- the API is weird and returns nil instead of 0
    if not blueprint_direction then
      blueprint_direction = real_direction
    end
    if blueprint_direction ~= real_direction then return nil end
  end
  return blueprint_direction
end

---compute the direction of a square in a direction array
---@param direction_array any
---@param square any
---@return number|nil the direction of the square or nil if the directions in the direction array do not all match direction
function compute_square_direction(direction_array, square)
  local square_direction = nil
  for i=square.x-square.size+1,square.x do
    for j=square.y-square.size+1,square.y do
      if not square_direction then
        square_direction = direction_array[i][j]
      end
      if square_direction ~= direction_array[i][j] then return nil end 
    end
  end
  return square_direction
end

function on_pre_build(event)
  -- verify this is a pre_build event for a blueprint being stamped down
  local player = game.players[event.player_index]
  if not (player.cursor_stack and player.cursor_stack.valid and player.cursor_stack.valid_for_read and player.cursor_stack.is_blueprint and player.cursor_stack.is_blueprint_setup()) then return end

  -- pre_build does not give the location of the blueprint paste, so we co-opt the custom input event from on_belt_turner to get the position
  -- since the custom input event can exactly match stamping a blueprint down with a  linked_game_control of "build-ghost" and it gets the cursor position
  -- this does mean the logic here relies on the custom input event being fired before on_pre_build which is empirically the case but not technically a part of the
  -- API as best I can find
  local cursor_position = global.cursor_positions[event.player_index]
  if not cursor_position then return end

  -- compute blueprint aabb so we know the bounds to search for belts to turn
  -- also checks that all the entities in the blueprint are belts so we can fail-fast
  -- if they are not and avoid wasting compute resources when unnecessary
  local blueprint = player.cursor_stack
  local blueprint_entities = blueprint.get_blueprint_entities()
  local xmin, xmax, ymin, ymax = compute_blueprint_aabb(blueprint_entities)
  if not (xmin and xmax and ymin and ymax) then return end

  -- compute aabb center since we need to treat the blueprint entities as relative to this point
  local blueprint_center = {
    x=(xmin + xmax) / 2,
    y=(ymin + ymax) / 2,
  }
  -- compute difference between the cursor position and the blueprint aabb center to understand the relative
  -- change in position required to map blueprint entities to their pasted position
  local delta = pos_sub(cursor_position, blueprint_center)

  -- compute the direction the blueprint belts point and determine the width of the belt lines we are turning
  local blueprint_direction = compute_blueprint_direction(blueprint_entities)
  local brush_width = math.min(ymax - ymin, xmax - xmin) + 1 -- the width is the min side length of the rectangle since we require a rectangle to be able to detect the turning event
  if not blueprint_direction then return end

  -- the direction of the belts in the blueprint is not the direction of the pasted belts
  -- so we compute the pasted blueprint direction by modifying the direction by the direction of the paste from the event
  -- mod 8 because factorio directions are in mod 8 
  -- TODO will this change in 2.0 with 16 direction rails
  local pasted_blueprint_direction = (blueprint_direction + event.direction) % 8

  -- compute the AABB of the pasted location using the transformation logic on the blueprint AABB
  local t_xmin, t_xmax, t_ymin, t_ymax = transform_aabb(delta, event.direction, xmin, xmax, ymin, ymax, blueprint_center)
  local area = {left_top={x=math.floor(t_xmin),y=math.floor(t_ymin)}, right_bottom={x=math.floor(t_xmax)+1,y=math.floor(t_ymax)+1}}
  local surface = player.surface

  -- determine if there is a square of size equal to the width of the belt line we are turning inside the pasted AABB
  -- if this square is present, it is the square of belts in the corner of the existing belt line and the turned belt line
  -- being created by the pre_build blueprint stamp down event
  local array = compute_direction_array(surface, area)
  -- but while searching for the square, we want to skip over any belts matching the direction of the pasted blueprint
  -- (or the opposite direction of the pasted blueprint) since we wouldn't be interested in turning them and if 
  -- we consider them we waste computing time later trying to figure out if we should turn a square containing them
  -- when we can already ignore that square at this step
  local skip_directions = {}
  skip_directions[pasted_blueprint_direction] = true
  skip_directions[(pasted_blueprint_direction + 4) % 8] = true
  local candidate_square = find_square(array, area, skip_directions)
  if not candidate_square or candidate_square.size ~= brush_width then return end

  -- compute the direction of the square of belts that we might be turning
  local square_direction = compute_square_direction(array, candidate_square)

  -- if the paste direction is either the same or opposite the sqaure direction we can't make a 90 degree turn
  if pasted_blueprint_direction == square_direction or (pasted_blueprint_direction + 4) % 8 == square_direction then
    return
  end

  -- compute the direction in each of the 4 sides of the square
  -- but for checking the sides of the square we want to check a square with 1 additional row/column on each side of the original square
  -- which could be accomplished by taking the original square and expanding it by 1 but taking the blueprint rectangle and expanding it
  -- by 1 will contain this desired square while still containing all blueprint entity positions
  local area_extension = {left_top={x=area.left_top.x-1,y=area.left_top.y-1}, right_bottom={x=area.right_bottom.x+1,y=area.right_bottom.y+1}}

  -- this time we need to combine both the existing belts that already exist in the surface with the belts that are going to be pasted
  -- after this pre_build event completes so we have to combine the result of compute_direction_array with the directions of the transformed
  -- belt entities in the blueprint
  local array_extension = compute_direction_array(surface, area_extension)
  for _, blueprint_entity in pairs(blueprint_entities) do
    local xformed_pos = transform_blueprint_position(delta, event.direction, blueprint_entity.position, blueprint_center)
    local xformed_x = math.floor(xformed_pos.x)
    local xformed_y = math.floor(xformed_pos.y)
    -- we don't want to overwrite the positions already filled in with real entities with the to be pasted directions so skip those positions in the array
    if array_extension[xformed_x][xformed_y] < 0 then
      array_extension[xformed_x] = array_extension[xformed_x] or {}
      array_extension[xformed_x][xformed_y] = ((blueprint_entity.direction or 0 ) + event.direction) % 8 -- the API is weird and returns nil instead of 0
    end
  end

  -- some math to compute the rectangles representing the edges of the square that we might want to turn
  -- . R R R .
  -- R S S S R
  -- R S S S R
  -- R S S S R
  -- . R R R .
  -- in the above diagram the square of S represents the candidate_square position and each rectangle of R is one of the edge rectangles being computed below
  x_left = {left_top={x=candidate_square.x+1,y=candidate_square.y-candidate_square.size+1}, right_bottom={x=candidate_square.x+1,y=candidate_square.y}}
  x_right = {left_top={x=candidate_square.x-candidate_square.size,y=candidate_square.y-candidate_square.size+1}, right_bottom={x=candidate_square.x-candidate_square.size,y=candidate_square.y}}
  y_top = {left_top={x=candidate_square.x-candidate_square.size+1,y=candidate_square.y+1}, right_bottom={x=candidate_square.x,y=candidate_square.y+1}}
  y_bottom = {left_top={x=candidate_square.x-candidate_square.size+1,y=candidate_square.y-candidate_square.size}, right_bottom={x=candidate_square.x,y=candidate_square.y-candidate_square.size}}

  -- each of the edges of the square will have some direction (nil if all the entities along the edge don't match direction)
  -- so we can use the directions of the edges of the square to determine what the orientation of the belts in the square should be modified
  -- to to connect the edges correctly
  x_left_dir = compute_area_direction(array_extension, x_left)
  x_right_dir = compute_area_direction(array_extension, x_right)
  y_top_dir = compute_area_direction(array_extension, y_top)
  y_bottom_dir = compute_area_direction(array_extension, y_bottom)

  -- the area to turn is just the candidate_square but we represent it as a bounding box here instead of a position + size
  local area_turn={left_top={x=candidate_square.x-brush_width+1,y=candidate_square.y-brush_width+1}, right_bottom={x=candidate_square.x,y=candidate_square.y}}

  -- this is the trial-and-error part where we chose which variant of turning the belts is required to connect the given directions
  -- we don't have to care about which direction was from the existing belts or from the blueprint here since the orientation of the
  -- belts in the square is only based on the incoming and outgoing direction
  -- note that the cases here don't cover every possible combination of the 4 directions for the 4 edges of the square
  -- but this is because there are only 8 possible belt turns so we look for them specifically
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

---finds the largest possible square inside some rectangle area
---ignoring all positions in the array that match the skipped directions
---@param array any
---@param area any
---@param skip_directions any
---@return table|nil
function find_square(array, area, skip_directions)
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
      if array[i][j] >= 0 and not skip_directions[array[i][j]] then
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
  if max_size == -1 then return nil end

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

---compute the direction that an area faces or nil if it doesn't all face the same direction
---compute this from the computed direction array since they must have been present
---@param array_extension any
---@param area any
---@return number|nil
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

function on_belt_turner(event)
  -- ensure this is a valid blueprint stamped down event
  local player = game.players[event.player_index]
  if not (player.cursor_stack and player.cursor_stack.valid and player.cursor_stack.valid_for_read and player.cursor_stack.is_blueprint and player.cursor_stack.is_blueprint_setup()) then return end

  -- save the position the blueprint is being stamped
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