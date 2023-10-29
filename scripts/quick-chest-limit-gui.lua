QuickChestLimitGui = {}

QuickChestLimitGui.name_gui_root = "quick-chest-limit"

QuickChestLimitGui.chest_types = { "container", "infinity-container", "linked-container", "logistic-container" }
QuickChestLimitGui.slots_per_row = 10

local fns = {}

function fns.table_contains(table, target)
  for _, item in pairs(table) do
    if item == target then return true end
  end
  return false
end

function QuickChestLimitGui.gui_open(player, inventory)
  QuickChestLimitGui.gui_close(player)
  if not (player.opened and player.opened.valid) then return end

  local gui = player.gui.relative

  local anchor = {gui=defines.relative_gui_type.container_gui, position=defines.relative_gui_position.right}

  if player.opened.type == "linked-container" then
    anchor.gui = defines.relative_gui_type.linked_container_gui
  end

  local container = gui.add{
    type = "frame",
    name = QuickChestLimitGui.name_gui_root,
    direction="vertical",
    anchor = anchor,
  }

  local title_flow = container.add{type = "flow", name = "title-flow", direction = "horizontal"}
  title_flow.add{type = "label", name = "title-label", style = "frame_title", caption = {"quick-chest-limit.set-limit"}, ignored_by_interaction = true}
  local title_empty = title_flow.add{
    type = "empty-widget",
    ignored_by_interaction = true
  }
  title_empty.style.horizontally_stretchable = "on"
  title_empty.style.left_margin = 4
  title_empty.style.right_margin = 0
  title_empty.style.height = 24

  local gui_inner = container.add{type="frame", name="gui_inner", direction="vertical", style="item_and_count_select_background"}
  gui_inner.style.padding = 10

  local slot_label = gui_inner.add{type="label", name="slot-label", style="heading_3_label", caption = {"quick-chest-limit.slots"}}

  local slot_button_frame = gui_inner.add{
    type="frame",
    name="slot_button_frame",
    direction="horizontal",
    style = "slot_button_deep_frame"
  }

  local number_of_slots = #inventory
  local max_rows = math.floor(number_of_slots / QuickChestLimitGui.slots_per_row)

  for i=1,5 do
    slot_button_frame.add{
      type="sprite-button",
      sprite="virtual-signal/signal-"..i,
      tags={
        action = "quick-chest-limit-slots",
        count = i
      },
      tooltip = {"quick-chest-limit.slot-tooltip", i},
      style = "slot_button",
    }
  end

  local row_label = gui_inner.add{type="label", name="row-label", style="heading_3_label", caption = {"quick-chest-limit.rows"}}

  local row_button_frame = gui_inner.add{
    type="frame",
    name="row_button_frame",
    direction="horizontal",
    style = "slot_button_deep_frame"
  }

  for i=1,math.min(5,max_rows) do
    row_button_frame.add{
      type="sprite-button",
      sprite="virtual-signal/signal-"..i,
      tags={
        action = "quick-chest-limit-rows",
        count = i
      },
      tooltip = {"quick-chest-limit.row-tooltip", i},
      style = "slot_button",
    }
  end

  local clear_button = gui_inner.add{
    type="button",
    name="clear-button",
    tags={
      action = "quick-chest-limit-clear"
    },
    caption = {"quick-chest-limit.clear-limit"}
  }
  clear_button.style.horizontal_align = "center"
  clear_button.style.horizontally_stretchable = "on"
  clear_button.style.top_margin = 10
end

function QuickChestLimitGui.on_gui_click(event)
  local player = game.players[event.player_index]
  if not (event.element and event.element.tags and event.element.tags.action) then return end
  if not (player.opened and player.opened.valid) then return end
  local inventory = player.opened.get_inventory(defines.inventory.chest)
  if not (inventory and inventory.valid and inventory.supports_bar()) then return end
  local element = event.element
  if element.tags.action == "quick-chest-limit-slots" then
    inventory.set_bar(element.tags.count + 1)
  elseif element.tags.action == "quick-chest-limit-rows" then
    inventory.set_bar(element.tags.count * QuickChestLimitGui.slots_per_row + 1)
  elseif element.tags.action == "quick-chest-limit-clear" then
    inventory.set_bar()
  end
end
script.on_event(defines.events.on_gui_click, QuickChestLimitGui.on_gui_click)

function QuickChestLimitGui.gui_close(player)
  if player.gui.relative[QuickChestLimitGui.name_gui_root] then
    player.gui.relative[QuickChestLimitGui.name_gui_root].destroy()
  end
end

function QuickChestLimitGui.on_gui_closed(event)
  local player = game.players[event.player_index]
  if player and event.entity and event.entity.valid and fns.table_contains(QuickChestLimitGui.chest_types, event.entity.type) then
    QuickChestLimitGui.gui_close(player)
  end
end
script.on_event(defines.events.on_gui_closed, QuickChestLimitGui.on_gui_closed)

function QuickChestLimitGui.on_gui_opened(event)
  local player = game.players[event.player_index]
  if not (player and event.entity and event.entity.valid and fns.table_contains(QuickChestLimitGui.chest_types, event.entity.type)) then return end
  if not (player.opened and player.opened.valid) then return end
  local inventory = player.opened.get_inventory(defines.inventory.chest)
  if not (inventory and inventory.valid and inventory.supports_bar()) then return end
  QuickChestLimitGui.gui_open(player, inventory)
end
script.on_event(defines.events.on_gui_opened, QuickChestLimitGui.on_gui_opened)

return QuickChestLimitGui